import tkinter as tk
from tkinter import filedialog, simpledialog
import csv

DELETE_BG_COLOR = "#ff4d4d"
DELETE_PRESS_COLOR = "#ff9d9d"

BUTTON_BG_COLOR = "#4d4dff"
BUTTON_PRESS_COLOR = "#9d9dff"

MIN_LISTBOX_HEIGHT = 40

DEFAULT_CANVAS_SIZE = 600

DEFAULT_POINT_RADIUS = 6
MAX_RADIUS = 20
MIN_RADIUS = 1

DEFAULT_ARROW_THICKNESS = 3
MAX_THICKNESS = 10
MIN_THICKNESS = 1

class ReorderListApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Path Creator")
        root.geometry("768x1024")
        root.minsize(768, 1024)
        root.configure(bg="lightblue")
        
        self.point_radius = DEFAULT_POINT_RADIUS
        self.arrow_thickness = DEFAULT_ARROW_THICKNESS
        self.arrows_enabled = True
        
        self.items = []
        self.selected_index = None
        self.dragged_index = None
        

        canvas_size = DEFAULT_CANVAS_SIZE
        canvas_height = canvas_width = canvas_size
        listbox_width = 12

        tutorial_font_size = 12
        top_frame = tk.Frame(root, bg="lightblue")
        top_frame.grid(row=0, column=0, columnspan=2, pady=10, sticky="ew")
        
        self.info_label = tk.Label(top_frame, text="   Path Creator - Instructions:", font=("TkDefaultFont", tutorial_font_size, 'bold'), bg="lightblue", anchor='w')
        self.info_label.grid(row=0, column=0, sticky="ew")
        
        self.info_label0 = tk.Label(top_frame, text="         Canvas:", font=("TkDefaultFont", tutorial_font_size, ), bg="lightblue", anchor='w')
        self.info_label0.grid(row=1, column=0, sticky="ew")
        
        self.info_label1 = tk.Label(top_frame, text="               Left-click the canvas to add a new point to the list. Left-click a point on the canvas to select it.", font=("TkDefaultFont", tutorial_font_size, ), bg="lightblue", anchor='w')
        self.info_label1.grid(row=2, column=0, sticky="ew")

        self.info_label2 = tk.Label(top_frame, text="               When a point is selected, arrow keys can be used for fine location adjustment of the point.", font=("TkDefaultFont", tutorial_font_size, ), bg="lightblue", anchor='w')
        self.info_label2.grid(row=3, column=0, sticky="ew")

        self.info_label3 = tk.Label(top_frame, text="               Right-click the canvas to customize viewing options.", font=("TkDefaultFont", tutorial_font_size, ), bg="lightblue", anchor='w')
        self.info_label3.grid(row=4, column=0, sticky="ew")

        self.info_label4 = tk.Label(top_frame, text="         List:", font=("TkDefaultFont", tutorial_font_size, ), bg="lightblue", anchor='w')
        self.info_label4.grid(row=5, column=0, sticky="ew")
        
        self.info_label5 = tk.Label(top_frame, text="               Left-click the point list to select a point. Click-and-drag to reorder the points.", font=("TkDefaultFont", tutorial_font_size, ), bg="lightblue", anchor='w')
        self.info_label5.grid(row=6, column=0, sticky="ew")
        
        self.info_label6 = tk.Label(top_frame, text="               Right-click the list to save and load point lists or to delete the selected point or all points", font=("TkDefaultFont", tutorial_font_size, ), bg="lightblue", anchor='w')
        self.info_label6.grid(row=7, column=0, sticky="ew")
        
        self.info_label7 = tk.Label(top_frame, text="         Debugging:", font=("TkDefaultFont", tutorial_font_size, ), bg="lightblue", anchor='w')
        self.info_label7.grid(row=8, column=0, sticky="ew")
        
        self.info_label8 = tk.Label(top_frame, text="               Debgging information or previous events are shown in the black text box at the bottom.", font=("TkDefaultFont", tutorial_font_size, ), bg="lightblue", anchor='w')
        self.info_label8.grid(row=9, column=0, sticky="ew")

        listbox_frame = tk.Frame(root)
        listbox_frame.grid(row=2, column=0, padx=10, pady=10, sticky="ns")  

        self.listbox = tk.Listbox(listbox_frame, selectmode=tk.SINGLE, width=listbox_width, height=MIN_LISTBOX_HEIGHT, activestyle="none", border=0, borderwidth=0, highlightthickness=0, highlightcolor='lightblue')
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
        self.canvas.grid(row=2, column=1, padx=10, pady=10)

        self.canvas.bind("<Button-1>", self.canvas_click)
        self.canvas.bind("<Button-3>", self.show_canvas_context_menu)
        
        self.root.bind("<KeyPress-Left>", self.move_selected_point)
        self.root.bind("<KeyPress-Right>", self.move_selected_point)
        self.root.bind("<KeyPress-Up>", self.move_selected_point)
        self.root.bind("<KeyPress-Down>", self.move_selected_point)
        
        self.canvas.focus_set()

        self.error_label = tk.Label(self.root, text="", fg="red", bg="black", width=100, height=2, anchor="w")
        self.error_label.grid(row=3, column=0, columnspan=2, padx=10, pady=10, sticky="w")

        self.context_menu = tk.Menu(self.root, tearoff=0)
        self.context_menu.add_command(label="Save path as csv", command=self.save_to_csv, activebackground="blue")
        self.context_menu.add_command(label="Load path as csv", command=self.load_from_csv, activebackground="blue")
        self.context_menu.add_separator()
        self.context_menu.add_command(label="Delete selected point", command=self.delete_selected_item, activebackground="red")
        self.context_menu.add_separator()
        self.context_menu.add_command(label="Clear all points", command=self.clear_items, activebackground="red")

        self.canvas_context_menu = tk.Menu(self.root, tearoff=0)
        self.canvas_context_menu.add_command(label="Set to default point radius", command=self.set_default_point_radius, activebackground="blue")
        self.canvas_context_menu.add_command(label="     Increase point radius", command=self.increase_point_radius, activebackground="blue")
        self.canvas_context_menu.add_command(label="     Decrease point radius", command=self.decrease_point_radius, activebackground="blue")
        self.canvas_context_menu.add_separator()
        self.canvas_context_menu.add_command(label="Set to default arrow thickness", command=self.set_default_arrow_thickness, activebackground="blue")
        self.canvas_context_menu.add_command(label="     Increase arrow thickness", command=self.increase_arrow_thickness, activebackground="blue")
        self.canvas_context_menu.add_command(label="     Decrease arrow thickness", command=self.decrease_arrow_thickness, activebackground="blue")
        self.canvas_context_menu.add_command(label=f"{'Disable arrows' if self.arrows_enabled else 'Enable arrows'}", command=self.set_arrows_state, activebackground="blue")
        self.canvas_context_menu.add_separator()
        self.canvas_context_menu.add_command(label="Delete selected point", command=self.delete_selected_item, activebackground="red")
        self.canvas_context_menu.add_separator()
        self.canvas_context_menu.add_command(label="Clear all points", command=self.clear_items, activebackground="red")


    
    def add_item(self, event):
        x, y = event.x, event.y
        self.items.append((x, y))
        self.display_error(f"Added point at ({x}, {y})")
        self.selected_index = len(self.items) - 1
        self.update_listbox()
        self.redraw_canvas()


    def delete_selected_item(self, event=None):
        if self.selected_index is None:
            self.display_error("no point selected for deletion")
            return
        x, y = self.items[self.selected_index]
        self.display_error(f"deleted point at ({x}, {y})")
        self.items.pop(self.selected_index)
        self.update_listbox()
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
        self.display_error("cleared the points in the current path")


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
            
            if self.arrows_enabled:
                for i in range(1, len(self.items)):
                    x1, y1 = self.items[i - 1]
                    x2, y2 = self.items[i]
                    self.canvas.create_line(x1, y1, x2, y2, arrow=tk.LAST, width=self.arrow_thickness, fill="gray")
            
            for index, item in enumerate(self.items):
                color = "red" if index == self.selected_index else "black"
                self.canvas.create_oval(item[0] - self.point_radius, item[1] - self.point_radius, 
                                        item[0] + self.point_radius, item[1] + self.point_radius, fill=color, outline=color)


    def canvas_click(self, event):
        for index, (x, y) in enumerate(self.items):
            if (x - event.x) ** 2 + (y - event.y) ** 2 <= (self.point_radius ** 2):
                self.listbox.select_clear(0, tk.END)
                self.listbox.select_set(index)
                self.selected_index = index
                self.highlight_selection()
                return 
        self.add_item(event) 


    def save_to_csv(self):
        if len(self.items) == 0:
            self.display_error("the drawn path is empty, nothing to save")
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
            self.display_error("the current path needs to be empty to load a file")
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
        

    def show_canvas_context_menu(self,event):
        self.canvas_context_menu.post(event.x_root, event.y_root)


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
            
            
    def increase_point_radius(self):
        prev = self.point_radius
        self.point_radius += 1
        if self.point_radius > MAX_THICKNESS:
            self.point_radius = MAX_THICKNESS
        self.display_error(f"point radius has changed from {prev} to {self.point_radius}")
        self.redraw_canvas()
            
    def decrease_point_radius(self):
        prev = self.point_radius
        self.point_radius -= 1
        if self.point_radius < MIN_RADIUS:
            self.point_radius = MIN_RADIUS
        self.display_error(f"point radius has changed from {prev} to {self.point_radius}")

        self.redraw_canvas()
        
    def set_default_point_radius(self):
        self.point_radius = DEFAULT_POINT_RADIUS
        self.display_error(f"point radius has been set default {self.point_radius}")
        self.redraw_canvas()

        
        
    def increase_arrow_thickness(self):
        prev = self.arrow_thickness
        self.arrow_thickness += 1
        if self.arrow_thickness > MAX_THICKNESS:
            self.arrow_thickness = MAX_THICKNESS
        self.display_error(f"arrow thickness has changed from {prev} to {self.arrow_thickness}")
        if not self.arrows_enabled:
            self.set_arrows_state()
        self.redraw_canvas()
        
    def decrease_arrow_thickness(self):
        prev = self.arrow_thickness
        self.arrow_thickness -= 1
        if self.arrow_thickness < MIN_THICKNESS:
            self.arrow_thickness = MIN_THICKNESS
        self.display_error(f"arrow thickness has changed from {prev} to {self.arrow_thickness}")
        if not self.arrows_enabled:
            self.set_arrows_state()
        self.redraw_canvas()
        
    def set_default_arrow_thickness(self):
        self.arrow_thickness= DEFAULT_ARROW_THICKNESS
        self.display_error(f"arrow thickness has been set default {self.arrow_thickness}")
        if not self.arrows_enabled:
            self.set_arrows_state()
        self.redraw_canvas()
                
            
    def set_arrows_state(self):
        self.arrows_enabled = not self.arrows_enabled
        status = "enabled" if self.arrows_enabled else "disabled"
        self.display_error(f"arrows are now {status}")
        self.canvas_context_menu.entryconfig(7, label=f"{'Disable arrows' if self.arrows_enabled else 'Enable arrows'}")
        self.redraw_canvas()

if __name__ == "__main__":
    root = tk.Tk()
    app = ReorderListApp(root)
    root.mainloop()
