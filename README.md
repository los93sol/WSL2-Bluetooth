# WSL2 Bluetooth
Getting Bluetooth going in WSL 2 is typically a fair amount of work and it's a minefield.  Hopefully this is helpful for someone somewhere!

Initialize.ps1 simplifies this by doing the following...  
1. Ensures WSL2 is setup with a default Ubuntu distro  
2. Creates a temp distro to compile the kernel with Bluetooth support  
3. Creates the .wslconfig file to point at the new kernel  
4. Reloads WSL to apply the new kernel  
5. Adds the app user UID 1654 (Specific to .NET containers running as non-root user)  
6. Ensures the bluetooth group is created  
7. Adds the app user to the bluetooth group  
8. Ensures dbus is running  
9. Installs bluez  
10. Ensures bluetooth is running  
11. Installs linux-tools-virtual  
12. Installs usbipd-win  
13. Installs docker desktop  

To run this...
1. Open the solution in Visual Studio 2022
2. Run "Scripts/Development/Initialize.ps1" in the package manager window
3. Attach your bluetooth device to the ubuntu distro
4. Run bluetoothctl inside the .NET container and it will work

If you have any issues running the script...
1. Make sure you please make sure you can execute powershell with "Set-ExecutionPolicy RemoteSigned"
2. Make sure the line endings in BuildKernel.sh are Unix (LF), Notepad++ makes it simple to check/fix it.
