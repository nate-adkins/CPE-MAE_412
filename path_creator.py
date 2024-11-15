import tkinter as tk
from tkinter import filedialog
import csv

DELETE_BG_COLOR = "#ff4d4d"
DELETE_PRESS_COLOR = "#ff9d9d"

BUTTON_BG_COLOR = "#4d4dff"
BUTTON_PRESS_COLOR = "#9d9dff"

MIN_LISTBOX_HEIGHT = 10

class ReorderListApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Reorder List GUI")

        self.listbox = tk.Listbox(self.root, selectmode=tk.SINGLE, width=20, height=MIN_LISTBOX_HEIGHT, activestyle="none")
        self.listbox.grid(row=0, column=0, pady=10)

        self.items = []

        self.listbox.bind("<<ListboxSelect>>", self.highlight_selection)
        self.listbox.bind("<Button-1>", self.start_drag)
        self.listbox.bind("<B1-Motion>", self.drag)
        self.listbox.bind("<ButtonRelease-1>", self.stop_drag)
        self.listbox.bind("<Delete>", self.delete_selected_item)
        self.listbox.bind("<Button-3>", self.show_context_menu)

        # Input frame for Add item
        self.input_frame = tk.Frame(self.root)
        self.input_frame.grid(row=1, column=0, pady=10)

        self.value1_entry = tk.Entry(self.input_frame, width=10)
        self.value1_entry.grid(row=0, column=0, padx=5)
        self.value2_entry = tk.Entry(self.input_frame, width=10)
        self.value2_entry.grid(row=0, column=1, padx=5)

        self.add_button = tk.Button(self.input_frame, text="Add item", command=self.add_item, 
                                    borderwidth=0, highlightthickness=0, relief="flat", 
                                    activebackground=BUTTON_PRESS_COLOR, background=BUTTON_BG_COLOR)
        self.add_button.grid(row=0, column=2, padx=5)

        # Error message label
        self.error_label = tk.Label(self.root, text="", fg="red", bg="black", width=50, height=2, anchor="w")
        self.error_label.grid(row=4, column=0, pady=(10, 0), sticky="ew")

        self.dragged_index = None

        # Context menu
        self.context_menu = tk.Menu(self.root, tearoff=0)
        self.context_menu.add_command(label="Clear", command=self.clear_items)
        self.context_menu.add_command(label="Load CSV", command=self.load_from_csv)
        self.context_menu.add_command(label="Save as CSV", command=self.save_to_csv)
        self.context_menu.add_separator()  # Add a separator before the delete command

        # To keep track of which item was right-clicked
        self.right_clicked_item_index = None

    def add_item(self):
        try:
            value1 = int(self.value1_entry.get())
            value2 = int(self.value2_entry.get())
        except ValueError:
            self.display_error("2 integer values were not provided")
            self.value1_entry.delete(0, tk.END)
            self.value2_entry.delete(0, tk.END)

        item = (value1, value2)
        
        self.items.append(item)
        self.listbox.insert(tk.END, f"{value1}, {value2}")
        
        # Adjust Listbox height to accommodate new items
        self.update_listbox_size()

        self.value1_entry.delete(0, tk.END)
        self.value2_entry.delete(0, tk.END)

        self.clear_error()

    def delete_selected_item(self, event=None):
        selected_index = self.listbox.curselection()
        if not selected_index:
            self.display_error("no item is selected")
            return
        index = selected_index[0]
        self.items.pop(index)
        self.listbox.delete(index)

        # Adjust Listbox height after deletion
        self.update_listbox_size()

        self.clear_error()

    def start_drag(self, event):
        self.dragged_index = self.listbox.nearest(event.y)

    def drag(self, event):
        if self.dragged_index is not None:
            new_index = self.listbox.nearest(event.y)
            if new_index != self.dragged_index:
                self.items.insert(new_index, self.items.pop(self.dragged_index))
                self.update_listbox()
                self.dragged_index = new_index

    def stop_drag(self, event=None):
        self.dragged_index = None

    def clear_items(self, event=None):
        self.items.clear()
        self.listbox.delete(0, tk.END)

        # Adjust Listbox height after clearing all items
        self.update_listbox_size()

        self.clear_error()

    def highlight_selection(self, event=None):
        self.listbox.configure(selectbackground="gray", selectforeground="white")

        selected_index = self.listbox.curselection()
        index = selected_index[0] if selected_index else None

        for i in range(self.listbox.size()):
            if i == index:
                self.listbox.itemconfig(i, {'bg': 'lightblue'})
            else:
                self.listbox.itemconfig(i, {'bg': 'white'})

    def update_listbox(self):
        self.listbox.delete(0, tk.END)
        for item in self.items:
            self.listbox.insert(tk.END, f"{item[0]}, {item[1]}")
        self.highlight_selection()

    def save_to_csv(self):
        if len(self.items) == 0:
            self.display_error("list is empty")
            return

        file_path = filedialog.asksaveasfilename(defaultextension=".csv", filetypes=[("CSV Files", "*.csv")])

        if file_path:
            try:
                with open(file_path, mode='w', newline='') as file:
                    writer = csv.writer(file)
                    writer.writerow(["x", "y"])
                    writer.writerows(self.items)

                self.clear_error()
            except Exception as e:
                self.display_error(f"error saving file: {e}")

    def load_from_csv(self):
        file_path = filedialog.askopenfilename(filetypes=[("CSV Files", "*.csv")])

        if file_path:
            self.clear_items()

            try:
                with open(file_path, mode='r') as file:
                    reader = csv.reader(file)
                    next(reader)  # Skip header row
                    for row in reader:
                        if len(row) == 2:
                            self.items.append((row[0], row[1]))
                            self.listbox.insert(tk.END, f"{row[0]}, {row[1]}")
                self.update_listbox()
                self.clear_error()
            except Exception as e:
                self.display_error(f"error loading file: {e}")
            self.update_listbox_size()


    def show_context_menu(self, event):
        """Display context menu on right-click."""
        # Get the index of the item clicked
        index = self.listbox.nearest(event.y)

        # If no item is selected, auto-select the closest one
        if not self.listbox.curselection():
            self.listbox.selection_clear(0, tk.END)
            self.listbox.selection_set(index)
            self.highlight_selection()

        if index is not None:
            # Set the index of the item right-clicked for future reference
            self.right_clicked_item_index = index
            # Clear the context menu and add the delete option
            self.context_menu.delete(0, tk.END)
            self.context_menu.add_command(label="delete selected", activebackground=DELETE_PRESS_COLOR, command=self.delete_right_clicked_item)
            self.context_menu.add_separator()  # Add a separator before the other commands
            self.context_menu.add_command(label="clear all", command=self.clear_items)
            self.context_menu.add_command(label="load from csv", command=self.load_from_csv)
            self.context_menu.add_command(label="save as csv", command=self.save_to_csv)
        
        self.context_menu.post(event.x_root, event.y_root)

    def delete_right_clicked_item(self):
        """Delete the item that was right-clicked."""
        if self.right_clicked_item_index is not None:
            self.items.pop(self.right_clicked_item_index)
            self.listbox.delete(self.right_clicked_item_index)
            self.right_clicked_item_index = None

            # Adjust Listbox height after deletion
            self.update_listbox_size()

            self.clear_error()

    def update_listbox_size(self):
        """Dynamically adjust the Listbox height to fit the list items."""
        # Set the height to match the number of items, with a minimum height of 1
        self.listbox.config(height=max(len(self.items), MIN_LISTBOX_HEIGHT))

    def display_error(self, message):
        self.error_label.config(text=message)

    def clear_error(self):
        self.error_label.config(text="")

if __name__ == "__main__":
    root = tk.Tk()
    app = ReorderListApp(root)
    root.mainloop()
