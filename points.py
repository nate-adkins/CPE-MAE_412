import tkinter as tk
from tkinter import ttk
import csv
from datetime import datetime

class PointOrderingApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Point Ordering GUI")

        # Frame for the list and canvas
        self.left_frame = tk.Frame(root)
        self.left_frame.pack(side=tk.LEFT, fill=tk.Y)
        
        self.canvas_frame = tk.Frame(root)
        self.canvas_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)
        
        # Listbox to display points
        self.point_listbox = tk.Listbox(self.left_frame, width=20, height=25, selectmode=tk.SINGLE)
        self.point_listbox.pack(pady=10, padx=10, fill=tk.Y)
        self.point_listbox.bind("<Button-1>", self.on_listbox_click)
        self.point_listbox.bind("<B1-Motion>", self.drag_point)
        self.point_listbox.bind("<ButtonRelease-1>", self.reorder_points)

        # Canvas for point placement
        self.canvas = tk.Canvas(self.canvas_frame, width=600, height=400, bg="white")
        self.canvas.pack(fill=tk.BOTH, expand=True)
        
        # Name entry field
        self.name_label = tk.Label(self.left_frame, text="Enter Name:")
        self.name_label.pack(pady=5)
        self.name_entry = tk.Entry(self.left_frame, width=20)
        self.name_entry.pack(pady=5)
        self.name_entry.bind("<KeyRelease>", self.check_name)  # Check if the name is entered

        # Save Button (Initially disabled)
        self.save_button = tk.Button(self.left_frame, text="Save as CSV", command=self.save_to_csv, state=tk.DISABLED)
        self.save_button.pack(pady=5)

        # Delete Button
        delete_button = tk.Button(self.left_frame, text="Delete Point", command=self.delete_selected_point)
        delete_button.pack(pady=5)
        
        # Label for displaying coordinates
        self.coord_label = tk.Label(self.canvas_frame, text="", font=("Arial", 10), anchor="se")
        self.coord_label.place(relx=1.0, rely=1.0, anchor="se")
        
        # Data structures
        self.points = []
        self.ordered_pairs = []
        self.selected_point = None
        self.point_items = {}

        # Event binding for canvas
        self.canvas.bind("<Button-1>", self.add_or_select_point)
        self.canvas.bind("<Motion>", self.update_coordinates)

    def add_or_select_point(self, event):
        x, y = event.x, event.y
        existing_point = self.get_closest_point(x, y)
        
        if existing_point:
            self.select_point(existing_point)
        else:
            self.add_point(x, y)

    def add_point(self, x, y):
        point = (x, y)
        self.points.append(point)
        
        # Ensure that the full inferno scale is used
        color = self.get_inferno_color(len(self.points), len(self.points))
        
        point_item = self.canvas.create_oval(x-3, y-3, x+3, y+3, fill=color)
        self.point_items[point] = point_item
        
        self.point_listbox.insert(tk.END, f"({x}, {y})")
        self.point_listbox.itemconfig(tk.END, {'fg': color})
        
        # Draw arrows after adding each point
        self.redraw_arrows()

    def get_inferno_color(self, index, total_points):
        # Scale the index to cover the full inferno scale
        normalized_index = (index - 1) / (total_points - 1) if total_points > 1 else 0
        inferno_colors = [
            "#000004", "#1f0c48", "#550f6d", "#88226a", "#aa3e63",
            "#cb5c55", "#e97e2f", "#fbb61a", "#fdea63", "#fcffa4"
        ]
        color_index = int(normalized_index * (len(inferno_colors) - 1))
        return inferno_colors[color_index]

    def select_point(self, point):
        if self.selected_point:
            self.canvas.itemconfig(self.point_items[self.selected_point], fill=self.get_inferno_color(self.points.index(self.selected_point) + 1, len(self.points)))
        
        self.selected_point = point
        self.canvas.itemconfig(self.point_items[point], fill="yellow")
        
        index = self.points.index(point)
        self.point_listbox.select_clear(0, tk.END)
        self.point_listbox.select_set(index)

    def on_listbox_click(self, event):
        index = self.point_listbox.nearest(event.y)
        if index < len(self.points):
            self.select_point(self.points[index])

    def draw_arrow(self, start, end):
        self.canvas.create_line(start[0], start[1], end[0], end[1], arrow=tk.LAST, fill="blue", width=2, tags="arrow")

    def get_closest_point(self, x, y, threshold=10):
        for point in self.points:
            if (point[0] - x)**2 + (point[1] - y)**2 <= threshold**2:
                return point
        return None

    def drag_point(self, event):
        if self.point_listbox.curselection():
            index = self.point_listbox.curselection()[0]
            point_text = self.point_listbox.get(index)
            self.point_listbox.delete(index)
            self.point_listbox.insert(tk.ACTIVE, point_text)

    def reorder_points(self, event):
        self.canvas.delete("arrow")
        self.ordered_pairs.clear()
        new_points = []
        for i in range(self.point_listbox.size()):
            x, y = eval(self.point_listbox.get(i))
            new_points.append((x, y))
        
        self.points = new_points
        self.redraw_arrows()

    def redraw_arrows(self):
        # Remove old arrows
        self.canvas.delete("arrow")
        
        # Redraw new arrows based on the current points order
        self.ordered_pairs.clear()
        for i in range(len(self.points) - 1):
            start, end = self.points[i], self.points[i + 1]
            self.ordered_pairs.append((start, end))
            self.draw_arrow(start, end)

    def delete_selected_point(self):
        if self.selected_point:
            index = self.points.index(self.selected_point)
            self.canvas.delete(self.point_items[self.selected_point])
            del self.point_items[self.selected_point]
            self.points.pop(index)
            self.point_listbox.delete(index)
            self.selected_point = None
            self.canvas.delete("arrow")
            self.redraw_arrows()

    def save_to_csv(self):
        # Get the name from the entry and append the timestamp
        name = self.name_entry.get().strip()
        if name == "":
            return  # Don't save if no name is entered

        timestamp = datetime.now().strftime("_%Y_%m_%d_%H_%M_%S")
        filename = f"shapes/{name}{timestamp}.csv"

        with open(filename, "w", newline="") as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(["x", "y"])  # Header row with x, y

            for point in self.points:
                writer.writerow([point[0], point[1]])  # Only write x, y values

        print(f"Points saved to {filename}")

    def check_name(self, event):
        # Enable or disable the save button based on the name entry
        if self.name_entry.get().strip():
            self.save_button.config(state=tk.NORMAL)
        else:
            self.save_button.config(state=tk.DISABLED)

    def update_coordinates(self, event):
        x, y = event.x, event.y
        self.coord_label.config(text=f"({x}, {y})")

if __name__ == "__main__":
    root = tk.Tk()
    app = PointOrderingApp(root)
    root.mainloop()
