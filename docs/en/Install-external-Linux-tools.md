# Install external Linux tools

**Can I, as an administrator, install additional tools on the HIN Gateway virtual machine?**

Yes. Administrators can install additional Linux tools on the HIN Gateway virtual machine, for example for diagnostics. Before you do, keep the following in mind.

## You are responsible for the tools you install

HIN Gateway does not manage or support third-party software installed on the virtual machine. Make sure the tools you add do not use excessive CPU, memory or disk space, so that enough resources remain for the HIN Gateway services to run normally.

## Installed tools are removed during updates

Each HIN Gateway update replaces the virtual machine environment. Any additional tools are removed and you must reinstall them after the update.
