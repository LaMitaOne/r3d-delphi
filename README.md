# r3d-delphi
This is a very early, experimental Delphi port (Win64) of the R3D 3D-Engine wrapper for Raylib and the Kraft Physics Engine. 
      
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/r3d-delphi)
        
<img width="627" height="471" alt="Unbenannt" src="https://github.com/user-attachments/assets/208a58c2-a3cc-4b49-bcf7-bb7b438dbab6" />
     
⚠️ **DISCLAIMER:** This is an early alpha/0.1 version. Many features are untested, and things might break or crash. I ported the core unit to Delphi and stripped FPC directives so we can start experimenting with 3D and physics directly in VCL.

## 🛠️ Current State
- The core R3D and Kraft units compile in Delphi (Win64).
- Bundles the required 64-bit Windows DLLs (like `libwinpthread-1.dll` and `raylib.dll`) so it works out-of-the-box.
- Includes a basic VCL demo where a sphere falls via Kraft physics onto a static box and can be pushed around with the arrow keys.

## 📜 Credits & Origins
This project stands on the shoulders of these awesome open-source projects:
1. **R3D Wrapper:** Ported and fixed from the original FreePascal/Lazarus project [ray4laz_r3d by GuvaCode](https://github.com/GuvaCode/ray4laz_r3d).
2. **Kraft Physics Engine:** Created by Benjamin Rosseaux (used heavily in the [Castle Game Engine](https://castle-engine.io)).
3. **Model Engine:** from https://github.com/GuvaCode/raylib-TPS-prototype    
     
## 🚀 How to test the Demo
1. Clone this repository.
2. Open raylibPrototypeVCL in your Delphi IDE.
3. Compile and run as **Win64**.
4. Use your Arrow Keys to move the marble.


🌍 better Raylib delphi sample you can find now here: https://github.com/LaMitaOne/RaylibErosionStandaloneDelphi    
<img width="870" height="614" alt="Unbenannt" src="https://github.com/user-attachments/assets/8e150fa0-70fa-4eb1-b342-6cf469741092" />


