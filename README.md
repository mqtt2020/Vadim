# docs

There are two PDF files for remote upgrade POC:

	RemoteUpgradeviaTT-POC.pdf
	RemoteUpgradeviaMender-POC.pdf
	
The goal was to design and implement the remote upgrade for 
Earlysense devices installed on sites without arriving technician to the site.

# code examples

Example of my code with main focus on:

	Informative logs to allow fast tracking down to root cause of issues
	Clean code that can be read as a "newspaper"
	
# code examples: bash script

	Prepare the device for system upgrade (flushing new image to the running device)
	
# code examples: java

	Implementation of class to communicate with BLE device
	Based on using TinyB library for Java
	TinyB library was cross compiled with iWaves toolchain and added to the project