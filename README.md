# Exordos Core Base Image

This is a base image for Exordos Core project. The image contains all necessary tools and libraries to be used in Exordos installations.

The key features are:

- [Universal Agent](https://github.com/infraguys/gcl_sdk/wiki/universal_agent) service.
- Exordos root autoresize service. Tries to perform resize of the root partition at every boot if it's possible.
- Exordos bootstrap service. Runs the bootstrap scripts.

# 🛠️ Build

You need [DevTools](https://github.com/exordos/exordos) to build the image. Look the the [install](https://github.com/exordos/exordos/blob/master/README.md#install) section for details.


Run the build command:

```bash
exordos build -i ~/.ssh/key.pub -f .
```

Where `~/.ssh/key.pub` is your public key for the image.

Also you may set the `GEN_USER_PASSWD` environment variable to change the default user password.

```bash
export GEN_USER_PASSWD=secret
exordos build -i ~/.ssh/key.pub -f .
```

To build with local copy of the SDK, export the `LOCAL_GENESIS_SDK_PATH` environment variable:

```bash
export LOCAL_GENESIS_SDK_PATH=/path/to/gcl_sdk
exordos build -i ~/.ssh/key.pub -f .
``` 

# 🚀 Usage

Upload the image to your repository. Using API, CLI or web interface create a node with the image.

```bash
curl --location 'http://10.20.0.2:11010/v1/nodes/' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer ****' \
--data '{
    
    "name": "vm",
    "project_id": "f1f14cf1-1639-40dc-b725-757506a202b4",
    "root_disk_size": 15,
    "cores": 1,
    "ram": 1024,
    
    "image": "http://10.20.0.1:8080/exordos-base.raw"
}'
```

# 📃 Bootstrap scripts

For next images in hierarchy you can add scripts that are executed at the very first boot of the node. Actually it can be any executable file and not only bash scripts. Put your scripts in the `/var/lib/exordos/bootstrap/scripts` directory and they will be executed in the order of the files in the directory.