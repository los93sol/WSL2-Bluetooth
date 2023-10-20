# WSL2 Bluetooth
Getting Bluetooth going in WSL 2 is typically a fair amount of work and it's a minefield.

Initialize.ps1 simplifies this by doing the following...  
1. Ensures WSL2 is setup with a default Ubuntu distro  
2. Creates a temp distro to compile the kernel with Bluetooth support  
3. Creates the .wslconfig file to point at the new kernel  
4. Reloads WSL to apply the new kernel  
5. Adds the app user UI 1654 (Specific to .NET containers running as non-root user)  
6. Ensures the bluetooth group is created  
7. Adds the app user to the bluetooth group  
8. Ensures dbus is running  
9. Installs bluez  
10. Ensures bluetooth is running  
11. Installs linux-tools-virtual  
12. Installs usbipd-win  
13. Installs docker desktop  

If you have any issues running the script please make sure the line endings in BuildKernel.sh are Unix (LF), Notepad++ makes it simple to check/fix it.
