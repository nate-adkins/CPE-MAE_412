import tkinter as tk
from tkinter import filedialog, simpledialog
import csv

DELETE_BG_COLOR = "#ff4d4d"
DELETE_PRESS_COLOR = "#ff9d9d"

BUTTON_BG_COLOR = "#4d4dff"
BUTTON_PRESS_COLOR = "#9d9dff"

MIN_LISTBOX_HEIGHT = 40
DEFAULT_POINT_RADIUS = 6
DEFAULT_CANVAS_SIZE = 600

class ReorderListApp:
    def __init__(self, root):
        self.root = root
        self.root.title("")
        root.geometry("1024x768")
        root.minsize(1024, 768)
        root.configure(bg="lightblue")

        canvas_size = DEFAULT_CANVAS_SIZE
        canvas_height = canvas_width = canvas_size
        listbox_width = 12

        listbox_frame = tk.Frame(root)
        listbox_frame.grid(row=0, column=0, padx=10, pady=10, sticky="ns")  

        self.listbox = tk.Listbox(listbox_frame, selectmode=tk.SINGLE, width=listbox_width, height=MIN_LISTBOX_HEIGHT, activestyle="none",border=0, borderwidth=0, highlightthickness=0)
        self.listbox.grid(row=0, column=0, sticky="n") 

        self.scrollbar = tk.Scrollbar(listbox_frame, orient=tk.VERTICAL, command=self.listbox.yview)
        self.scrollbar.grid(row=0, column=1, sticky="ns")  
        self.listbox.config(yscrollcommand=self.scrollbar.set)
        

        self.listbox.bind("<<ListboxSelect>>", self.highlight_selection)
        self.listbox.bind("<Button-1>", self.start_drag)
        self.listbox.bind("<B1-Motion>", self.drag)
        self.listbox.bind("<ButtonRelease-1>", self.stop_drag)
        self.root.bind("<Delete>", self.delete_selected_item)
        self.listbox.bind("<Button-3>", self.show_context_menu)
        
        self.canvas = tk.Canvas(self.root, width=canvas_width, height=canvas_height, bg='white', border=0, borderwidth=0, highlightthickness=0)
        self.canvas.grid(row=0, column=1, padx=10, pady=10)

        self.canvas.bind("<Button-1>", self.canvas_click)
        self.canvas.bind("<Button-3>", self.show_context_menu)
        
        self.root.bind("<KeyPress-Left>", self.move_selected_point)
        self.root.bind("<KeyPress-Right>", self.move_selected_point)
        self.root.bind("<KeyPress-Up>", self.move_selected_point)
        self.root.bind("<KeyPress-Down>", self.move_selected_point)
        
        self.canvas.focus_set()


        self.point_radius = DEFAULT_POINT_RADIUS
        self.items = []
        self.selected_index = None
        self.dragged_index = None

        self.error_label = tk.Label(self.root, text="", fg="red", bg="black", width=100, height=2, anchor="w")
        self.error_label.grid(row=1, column=0, columnspan=2, padx=10, pady=10, sticky="w")

        self.context_menu = tk.Menu(self.root, tearoff=0)
        self.context_menu.add_command(label="Save as CSV", command=self.save_to_csv, activebackground="blue")
        self.context_menu.add_command(label="Load CSV", command=self.load_from_csv, activebackground="blue")
        self.context_menu.add_separator()
        self.context_menu.add_command(label="Clear", command=self.clear_items, activebackground="red")
        self.context_menu.add_separator()
        self.context_menu.add_command(label="Delete", command=self.delete_selected_item, activebackground="red")

        self.canvas_context_menu = tk.Menu(self.root, tearoff=0)
        self.canvas_context_menu.add_command(label="Set Point Radius", command=self.set_point_radius, activebackground="blue")
        self.canvas_context_menu.add_separator()
        self.canvas_context_menu.add_command(label="Clear", command=self.clear_items, activebackground="red")
        self.canvas_context_menu.add_separator()
        self.canvas_context_menu.add_command(label="Delete", command=self.delete_selected_item, activebackground="red")

        self.point_radius = DEFAULT_POINT_RADIUS
        
        self.items = []
        self.selected_index = None
        self.dragged_index = None


    def add_item(self, event):
        # Add a new point at the clicked position
        x, y = event.x, event.y
        self.items.append((x, y))
        self.display_error(f"Added point at ({x}, {y})")
        self.selected_index = len(self.items) - 1  # Select the new point
        self.update_listbox()
        self.redraw_canvas()


    def delete_selected_item(self, event=None):
        if self.selected_index is None:
            self.display_error("no point selected for deletion")
            return
        
        # Display the point being deleted
        x, y = self.items[self.selected_index]
        self.display_error(f"deleted point at ({x}, {y})")
        
        # Delete the selected point
        self.items.pop(self.selected_index)
        
        # Remove the point from the listbox
        self.update_listbox()
        
        # Reset the selected index after deletion
        self.selected_index = None
        self.redraw_canvas()


    def start_drag(self, event):
        self.dragged_index = self.listbox.nearest(event.y)


    def drag(self, event):
        if self.dragged_index is not None:
            new_index = self.listbox.nearest(event.y)
            if new_index != self.dragged_index:
                self.items.insert(new_index, self.items.pop(self.dragged_index))
                self.update_listbox()
                self.redraw_canvas()
                self.dragged_index = new_index
                self.listbox.select_set(new_index)


    def stop_drag(self, event=None):
        self.dragged_index = None
        self.highlight_selection()
        self.redraw_canvas()


    def clear_items(self, event=None):
        self.items.clear()
        self.listbox.delete(0, tk.END)
        self.redraw_canvas()
        self.display_error("cleared the points in the current path:")


    def highlight_selection(self, event=None):
        selected_index = self.listbox.curselection()
        index = selected_index[0] if selected_index else None
        self.selected_index = index
        self.redraw_canvas()


    def update_listbox(self):
        self.listbox.delete(0, tk.END)
        for item in self.items:
            self.listbox.insert(tk.END, f"{item[0]}, {item[1]}")
        if self.selected_index is not None:
            self.listbox.select_set(self.selected_index)


    def redraw_canvas(self):
        self.canvas.delete("all")
        for index, item in enumerate(self.items):
            color = "red" if index == self.selected_index else "black"
            self.canvas.create_oval(item[0] - self.point_radius, item[1] - self.point_radius, 
                                    item[0] + self.point_radius, item[1] + self.point_radius, fill=color, outline=color)


    def canvas_click(self, event):
        for index, (x, y) in enumerate(self.items):
            # Check if the click is within the point's radius
            if (x - event.x) ** 2 + (y - event.y) ** 2 <= self.point_radius ** 2:
                # Select the item in the listbox
                self.listbox.select_clear(0, tk.END)  # Clear all selections
                self.listbox.select_set(index)  # Select the clicked item
                self.selected_index = index  # Set the selected index
                self.highlight_selection()  # Update canvas to highlight the selected point
                return  # Exit the loop once the point is found
        self.add_item(event)  # If no point was clicked, add a new one


    def save_to_csv(self):
        if len(self.items) == 0:
            self.display_error("the drawn path is empty, not saving")
            return
        file_path = filedialog.asksaveasfilename(defaultextension=".csv", filetypes=[("CSV Files", "*.csv")])
        if file_path:
            try:
                with open(file_path, mode='w', newline='') as file:
                    writer = csv.writer(file)
                    writer.writerow(["x", "y"])
                    writer.writerows(self.items)
                self.display_error(f'saved file: {file_path}')
            except Exception as e:
                self.display_error(f"error saving file: {e}")

    def load_from_csv(self):
        if len(self.items) != 0:
            self.display_error("the current path needs to be empty to load")
            return
        file_path = filedialog.askopenfilename(filetypes=[("CSV Files", "*.csv")])
        if file_path:
            try:
                with open(file_path, mode='r') as file:
                    reader = csv.reader(file)
                    next(reader)
                    for row in reader:
                        if len(row) == 2:
                            x, y = int(row[0]), int(row[1])
                            self.items.append((x, y))
                            self.listbox.insert(tk.END, f"{x}, {y}")
                self.redraw_canvas()
                self.display_error(f'loaded file: {file_path}')
            except Exception as e:
                self.display_error(f"error loading file: {e}")

    def show_context_menu(self, event):
        self.context_menu.post(event.x_root, event.y_root)


    def display_error(self, error_message):
        self.error_label.config(text= " " + error_message)

    def move_selected_point(self, event):
        if self.selected_index is None:
            return

        x, y = self.items[self.selected_index]

        if event.keysym == "Left":
            x -= 1
        elif event.keysym == "Right":
            x += 1
        elif event.keysym == "Up":
            y -= 1
        elif event.keysym == "Down":
            y += 1

        self.items[self.selected_index] = (x, y)
        self.update_listbox()
        self.redraw_canvas()


    def set_point_radius(self):
        radius = simpledialog.askinteger("Set Point Radius", "Enter the new radius:", initialvalue=self.point_radius)
        if radius is not None and radius > 0:
            self.point_radius = radius
            self.redraw_canvas()


if __name__ == "__main__":
    root = tk.Tk()
    app = ReorderListApp(root)
    root.mainloop()
