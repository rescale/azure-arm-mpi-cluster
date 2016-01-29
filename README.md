# Provision a minimal Windows MPI cluster on Microsoft Azure

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Frescale%2Fazure-arm-mpi-cluster%2Fmaster%2Fazuredeploy.json" target="_blank">
	<img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Frescale%2Fazure-arm-mpi-cluster%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template allows you to deploy a minimal Windows MPI Cluster that can run MS-MPI
applications without having HPC Pack installed. In addition, a SSH server is also
installed to allow the cluster to be controlled from the command-line from any OS.

The first VM in the cluster is named N0, the second is N1, the third is N2, and so
on. The VMs are fronted by a load balancer that serves as a NAT instance. Inbound NAT
rules are configured to allow SSH and RDP access to every node in the cluster. The
default SSH and RDP ports (22 and 3389 respectively) can be used to connect to the
first node in the cluster (N0). Node N1 uses ports 23 and 3390, N2 uses ports 24 and
3391, and so on.

## Cluster Environment

A vanilla Windows Server R2 Datacenter image is used as the starting point. The
CustomScriptExtension is used to install a common set of packages on all nodes.

MS-MPI v7 is installed to every node in the cluster. The MPI launch service is also started
on all nodes.

The 64-bit pre-release version of the official Microsoft supported [OpenSSH server](https://github.com/PowerShell/Win32-OpenSSH/releases/tag/12_22_2015)
is installed on all nodes and the sshd service is started. sftp is also enabled for all nodes.

Finally, the Visual Studio 2013 x86 and x64 redists are also installed to every node in the cluster.

Node N0 exposes a SMB share on the temporary drive that every node in the cluster maps
to ```C:\shared```.

## Example Usage

1. First, if you are starting with source code, you will need to compile it for MSMPI. [This](http://blogs.technet.com/b/windowshpc/archive/2015/02/02/how-to-compile-and-run-a-simple-ms-mpi-program.aspx)
is a great post explaining how to build a simple hello world application with Visual Studio.

1. Click the Deploy to Azure button above and fill out the deployment parameters. In this example,
the following parameters are used:

    | Parameter | Value |
    | --------- | ----- |
    | ADMINUSERNAME | ryan |
    | VMSIZE | Standard_D2 |
    | VMCOUNT | 2 |

1. Once the cluster has started, make a note of the public IP address (40.76.38.78 in this case). You will
need this to connect to node N0.

1. Use sftp to copy your MPI binary to the shared directory.

    ```
    $ sftp ryan@40.76.38.78
    ryan@40.76.38.78's password:
    Connected to 40.76.38.78.
    sftp> put MPIHelloworld.exe
    Uploading MPIHelloworld.exe to C:/Users/ryan/MPIHelloworld.exe
    MPIHelloworld.exe                100% 8192     8.0KB/s   00:00
    sftp> bye
    ```

1. SSH into the N0 node and run your MPI application. First, the executable is copied into the SMB
share to distribute it to all of the nodes in the cluster. Then, we launch mpiexec to kick off the
hello world application. Specify the admin password you used in the ARM deployment for the -pwd switch.
    ```
    $ ssh ryan@40.76.38.78
    ryan@40.76.38.78's password:
    Microsoft Windows [Version 6.3.9600]
    (c) 2013 Microsoft Corporation. All rights reserved.

    ryan@N0 C:\Users\ryan>copy MPIHelloworld.exe C:\shared
            1 file(s) copied.

    ryan@N0 C:\Users\ryan>cd C:\shared

    ryan@N0 C:\shared>mpiexec -hosts 2 n0 1 n1 1 -pwd ****** -savecreds MPIHelloworld.exe
    Rank 1 received string Hello World from Rank 0
    ```

A few usage notes:
* After ssh'ing in to the N0 node you will be presented with a basic Command Prompt (note that this
is plain old cmd, not powershell).
* The first time you launch mpiexec, you will need to provide your password as explained [here](https://msdn.microsoft.com/en-us/library/windows/desktop/mt147726(v=vs.85).aspx).
The ```-pwd``` and ```-savecreds``` switches can be omitted on subsequent calls.
