from PIL import Image
import os

def create_image_grid_with_buffer(input_folder, output_image, grid_size, buffer):
    image_files = sorted([f for f in os.listdir(input_folder) if f.lower().endswith(('png', 'jpg', 'jpeg', 'bmp'))])
    
    if not image_files:
        raise ValueError("No valid image files found in the input folder.")

    n_images = len(image_files)
    n_grid_cells = grid_size[0] * grid_size[1]
    if n_images > n_grid_cells:
        raise ValueError(f"Grid size {grid_size} cannot fit all {n_images} images.")
    
    images = [Image.open(os.path.join(input_folder, file)).convert("RGB") for file in image_files]

    img_width, img_height = images[0].size
    for img in images:
        if img.size != (img_width, img_height):
            raise ValueError("All images must be the same size.")

    grid_width = (img_width + buffer) * grid_size[1] - buffer
    grid_height = (img_height + buffer) * grid_size[0] - buffer
    grid_image = Image.new("RGB", (grid_width, grid_height), color=(255, 255, 255)) 
    
    for index, img in enumerate(images):
        row = index // grid_size[1]
        col = index % grid_size[1]
        x_offset = col * (img_width + buffer)
        y_offset = row * (img_height + buffer)
        grid_image.paste(img, (x_offset, y_offset))

    grid_image.save(output_image)
    print(f"Grid image saved as {output_image}")
    
def main():
    input_folder = "path_creator\path_imgs"
    output_image = "path_creator\path_imgs\merged\merged.jpg"
    grid_size = (2,13)
    buffer = 10
    
    create_image_grid_with_buffer(input_folder, output_image, grid_size, buffer)
    
if __name__ == "__main__":
    main()

