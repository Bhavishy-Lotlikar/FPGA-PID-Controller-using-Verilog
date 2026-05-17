import tkinter as tk
from tkinter import ttk
import threading
import time
import re

try:
    from matplotlib.figure import Figure
    from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
except ImportError:
    print("Error: matplotlib is required. Please install it using: pip install matplotlib")
    exit()

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("Error: pyserial is required. Please install it using: pip install pyserial")
    exit()

class PIDApp:
    def __init__(self, root):
        self.root = root
        self.root.title("PID Simulator")
        self.root.geometry("1000x700")
        
        self.serial_port = None
        self.is_running = False
        
        self.time_data = []
        self.sp_data = []
        self.po_data = []
        self.ct_data = []
        self.start_time = time.time()
        
        self.current_sp = 0
        self.current_po = 0
        self.current_ct = 0
        
        self.create_widgets()
        
    def create_widgets(self):
        # Main layout
        self.root.configure(bg="#a0a0a0")
        
        # Left Panel
        left_frame = tk.Frame(self.root, width=250, bg="#a0a0a0")
        left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=10, pady=10)
        
        # --- Serial Config ---
        serial_frame = tk.Frame(left_frame, bg="#a0a0a0")
        serial_frame.pack(side=tk.TOP, fill=tk.X, pady=20)
        
        tk.Label(serial_frame, text="COM Port:", bg="#a0a0a0").grid(row=0, column=0, sticky="w", pady=5)
        self.port_combobox = ttk.Combobox(serial_frame, width=12)
        self.port_combobox.grid(row=0, column=1, padx=10, pady=5)
        self.refresh_ports()
        
        tk.Label(serial_frame, text="Baud Rate:", bg="#a0a0a0").grid(row=1, column=0, sticky="w", pady=5)
        self.baud_combobox = ttk.Combobox(serial_frame, width=12, values=["57600", "115200"])
        self.baud_combobox.grid(row=1, column=1, padx=10, pady=5)
        self.baud_combobox.current(0)  # Default 57600
        
        tk.Button(serial_frame, text="Refresh Ports", command=self.refresh_ports).grid(row=2, column=0, columnspan=2, pady=10)
        
        # --- Buttons ---
        btn_frame = tk.Frame(left_frame, bg="#a0a0a0")
        btn_frame.pack(side=tk.TOP, fill=tk.X, pady=50)
        
        self.btn_start = tk.Button(btn_frame, text="Start", width=20, bg="white", command=self.toggle_start)
        self.btn_start.pack(pady=10)
        
        tk.Button(btn_frame, text="Reset", width=20, bg="white", command=self.reset_data).pack(pady=10)

        # Status Label to show raw data or errors
        self.lbl_status = tk.Label(left_frame, text="Status: Waiting", bg="#a0a0a0", fg="blue", wraplength=200, justify="left")
        self.lbl_status.pack(side=tk.BOTTOM, pady=20)
        
        # Right Panel (Graph + Bottom labels)
        right_frame = tk.Frame(self.root, bg="#d3d3d3")
        right_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Graph
        self.fig = Figure(figsize=(8, 5), dpi=100)
        self.ax = self.fig.add_subplot(111)
        self.ax.set_facecolor('#d3d3d3')
        self.line_sp, = self.ax.plot([], [], label='Set Point', color='black')
        self.line_po, = self.ax.plot([], [], label='Actual Value', color='red')
        self.line_ct, = self.ax.plot([], [], label='Output %', color='green')
        self.ax.legend(loc='upper right')
        
        self.canvas = FigureCanvasTkAgg(self.fig, master=right_frame)
        self.canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)
        
        # Bottom Labels
        bottom_frame = tk.Frame(right_frame, bg="#a0a0a0")
        bottom_frame.pack(side=tk.BOTTOM, fill=tk.X, pady=10)
        
        # Left side bottom labels
        left_labels = tk.Frame(bottom_frame, bg="#a0a0a0")
        left_labels.pack(side=tk.LEFT, padx=50)
        
        self.lbl_sp = tk.Label(left_labels, text="Set Point\t\t0", bg="#a0a0a0", fg="black", font=("Arial", 12, "bold"))
        self.lbl_sp.pack(anchor="w", pady=2)
        
        self.lbl_ct = tk.Label(left_labels, text="Output %\t\t0", bg="#a0a0a0", fg="green", font=("Arial", 12, "bold"))
        self.lbl_ct.pack(anchor="w", pady=2)
        
        self.lbl_po = tk.Label(left_labels, text="Actual Value\t0", bg="#a0a0a0", fg="red", font=("Arial", 12, "bold"))
        self.lbl_po.pack(anchor="w", pady=2)
        
    def refresh_ports(self):
        ports = [port.device for port in serial.tools.list_ports.comports()]
        self.port_combobox['values'] = ports
        if ports:
            self.port_combobox.current(0)
            
    def toggle_start(self):
        if self.is_running:
            self.is_running = False
            self.btn_start.config(text="Start")
            self.lbl_status.config(text="Status: Stopped", fg="blue")
            if self.serial_port:
                self.serial_port.close()
        else:
            port = self.port_combobox.get()
            baud_str = self.baud_combobox.get()
            if not baud_str:
                self.lbl_status.config(text="Error: Select Baud Rate", fg="red")
                return
            baud = int(baud_str)
            if port:
                try:
                    self.serial_port = serial.Serial(port, baud, timeout=0.1)
                    self.is_running = True
                    self.btn_start.config(text="Stop")
                    self.lbl_status.config(text=f"Status: Connected {baud}", fg="green")
                    self.start_time = time.time()
                    threading.Thread(target=self.read_serial, daemon=True).start()
                    self.update_plot()
                except Exception as e:
                    self.lbl_status.config(text=f"Error: {str(e)}", fg="red")
                    print(f"Error opening serial port: {e}")
            else:
                self.lbl_status.config(text="Error: No COM port selected", fg="red")
                    
    def reset_data(self):
        self.time_data.clear()
        self.sp_data.clear()
        self.po_data.clear()
        self.ct_data.clear()
        self.ax.clear()
        self.ax.set_facecolor('#d3d3d3')
        self.line_sp, = self.ax.plot([], [], label='Set Point', color='black')
        self.line_po, = self.ax.plot([], [], label='Actual Value', color='red')
        self.line_ct, = self.ax.plot([], [], label='Output %', color='green')
        self.ax.legend(loc='upper right')
        self.canvas.draw()
        
        self.current_sp = 0
        self.current_po = 0
        self.current_ct = 0
        self.update_labels()
        
    def read_serial(self):
        while self.is_running and self.serial_port and self.serial_port.is_open:
            try:
                line = self.serial_port.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    print(f"RAW UART: {line}") # Print to terminal for debugging
                    
                    # Use re.search instead of match, to tolerate any garbage chars before SP
                    m = re.search(r"SP=(\d+),PO=(\d+),CT=(\d+)", line)
                    if m:
                        self.current_sp = int(m.group(1))
                        self.current_po = int(m.group(2))
                        self.current_ct = int(m.group(3))
                        
                        t = time.time() - self.start_time
                        self.time_data.append(t)
                        self.sp_data.append(self.current_sp)
                        self.po_data.append(self.current_po)
                        self.ct_data.append(self.current_ct)
                        
                        # Keep window moving (last 100 points)
                        if len(self.time_data) > 100:
                            self.time_data.pop(0)
                            self.sp_data.pop(0)
                            self.po_data.pop(0)
                            self.ct_data.pop(0)
                            
                        self.root.after(0, self.update_labels)
                        
                        # Update status with latest good read
                        self.root.after(0, lambda: self.lbl_status.config(text=f"Receiving...\nSP:{self.current_sp} PO:{self.current_po} CT:{self.current_ct}", fg="green"))
                    else:
                        # Print what we received if it didn't match
                        self.root.after(0, lambda: self.lbl_status.config(text=f"Garbage data: {line[:20]}...", fg="orange"))
            except Exception as e:
                print(f"Serial read error: {e}")
                
    def update_labels(self):
        self.lbl_sp.config(text=f"Set Point\t\t{self.current_sp}")
        self.lbl_po.config(text=f"Actual Value\t{self.current_po}")
        self.lbl_ct.config(text=f"Output %\t\t{self.current_ct}")
        
    def update_plot(self):
        if self.is_running:
            if self.time_data:
                self.line_sp.set_data(self.time_data, self.sp_data)
                self.line_po.set_data(self.time_data, self.po_data)
                self.line_ct.set_data(self.time_data, self.ct_data)
                
                self.ax.relim()
                self.ax.autoscale_view()
                self.canvas.draw()
                
            self.root.after(100, self.update_plot)

if __name__ == "__main__":
    root = tk.Tk()
    app = PIDApp(root)
    root.mainloop()
