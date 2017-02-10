import PackageDescription

let package = Package(
    name: "DeviceInput",
    dependencies: [
    	.Package(url: "https://github.com/sersoft-gmbh/Clibgrabdevice.git", majorVersion: 1)
    ]
)
