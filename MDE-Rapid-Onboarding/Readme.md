# Purpose
The goal of this repository is to provide baseline settings for a rapid deployment for Microsoft Defender for Endpoint using the security.microsoft.com management policies only for configuration.

Licensing Requirements: Microsoft Defender for Endpoint P2.

![Screenshot of the Threat and Vulnerability Management dashboard in Microsoft Defender for Endpoint.](https://github.com/microsoft/dchemistruck/blob/main/Images/TVM-Dashboard.png)

# What's Created?
The files in this repo populate the following areas in Intune:

 - **Endpoint Security**
	 - Antivirus Configurations
	 - Intelligence Update Rings
	 - Tamper Protection
   - Basic Firewall enablement
   - Attack Surface Reduction Rules

> WARNING! The 'Enforcement' version of these policies will break certain legacy applications that rely on unsecure practices, such as using LDAP (instead of LDAPS), Basic Authentication, NTLMv1, or executing JavaScript/Web requests from a PDF or Office file.

![Screenshot of the Device Configuration pane in the Microsoft Intune portal.](https://github.com/microsoft/dchemistruck/blob/main/Images/TVM-Configurations.png)
# Instructions
1. Download the [TVM-Baselines](https://github.com/microsoft/dchemistruck/blob/main/Intune-MDE-TVM-Baselines/TVM-Baselines.zip) zip file and extract all files to a temporary location.
2. Download the [IntuneManagement tool](https://github.com/Micke-K/IntuneManagement/archive/refs/heads/master.zip). Documentation [here](https://github.com/Micke-K/IntuneManagement).
3. Extract the **IntuneManagement** tool and run the executable **Start.cmd** as administrator. 
    > You may be prompted to **Unblock** the file or **Run Anyways**.
4. Sign in with a **Global Administrator** or **Security Administrator** account by clicking the profile icon in the top right of the tool.
	 >If this is your first time using this tool in a tenant, after you grant permissions on your initial sign in, you'll need to:  sign out, close the tool and reopen before you can import the settings.
5. Go to **Bulk** > **Import** and select the root folder of the **TVM-Baselines**. Then import.
![Screenshot of the IntuneManagent tool.](https://github.com/microsoft/dchemistruck/blob/main/Images/TVM-IntuneManagementTool.png)
6. All of the policies get imported as unassigned, so you'll need to assign them to a group for testing.
7. Note: these baselines do not include the tenant onboarding packages for Microsoft Defender for Endpoint.

