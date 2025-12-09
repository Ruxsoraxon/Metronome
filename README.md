# FPGA Metronome Project 🎶

**Final Project for Digital Logic Design (DLD) course**  
Implemented on an FPGA board using Verilog and Quartus Prime.

---

## 📌 Overview
This project is a **full-featured digital metronome** implemented in hardware.  
It generates precise tempo pulses, drives a buzzer and LEDs, and displays BPM or mode information on a 7‑segment display.  

The design demonstrates:
- Clock division and timing control
- Modular Verilog design
- Button debouncing and edge detection
- Multi-mode operation (Run, Time Signature, Accent, Visual)

---

## ⚙️ Features
- Adjustable tempo: **30–300 BPM**
- Multiple time signatures: **2/4, 3/4, 4/4, 6/8**
- Accent beats for measure emphasis
- Visual-only mode (LEDs + display without buzzer)
- Mode cycling via **KEY3**, option toggling via **KEY4**
- LED indicators for beat position
- 7‑segment display showing BPM or current mode

---

## 🛠️ Hardware Setup
- **FPGA Board**: Cyclone IV (50 MHz clock)
- **Inputs**:
  - KEY1 → Increase BPM
  - KEY2 → Decrease BPM
  - KEY3 → Cycle mode (Run → Time Sig → Accent → Visual → Run)
  - KEY4 → Toggle option (Start/Stop, select signature, enable/disable accent/visual)
- **Outputs**:
  - Buzzer (active low)
  - LEDs (beat indicators)
  - 7‑segment display (BPM or mode)

---

## 📂 Repository Structure
- `metronome.v` → Core metronome logic
- `metronome_display.v` → Top module with display + LED integration
- `simulation/` → Testbench and Questa simulation files
- `output_files/` → Quartus compilation reports and `.sof` bitstream
- `LICENSE` → MIT License
- `README.md` → Project documentation

---

## ▶️ How to Run
1. Open the project in **Intel Quartus Prime**.
2. Compile the design (`metronome_display.v` as top module).
3. Program the FPGA board with the generated `.sof` file.
4. Use the keys to control BPM and modes, observe LEDs, buzzer, and display.

---

## 📸 Demo
*(Optional: Add a GIF or short video of the FPGA board running the metronome here.)*

---

## 📜 License
This project is licensed under the **MIT License** — free to use, modify, and share.

---

## ✨ Acknowledgments
- Developed as part of the **Digital Logic Design course final project**.
- Tools: Quartus Prime, Questa simulation.
