# Purpose
The goal of this repository is to provide baseline settings to deploy via Microsoft Intune for macOS 10.15+ and Windows 10+ to remediate most of the Threat and Vulnerability Management (TVM) recommendations from the Microsoft Defender for Endpoint TVM portal. Ignoring software updates, these baselines should reduce your Device Exposure score to about 10/100.

Licensing Requirements: Intune, Microsoft Defender for Endpoint P2.

![Screenshot of the Threat and Vulnerability Management dashboard in Microsoft Defender for Endpoint.](https://github.com/microsoft/dchemistruck/blob/main/Images/TVM-Dashboard.png)

# What's Created?
The files in this repo populate the following areas in Intune:

 - **Devices**
	 - Compliance Policies
	 - Configuration Policies
	 - Scripts
 - **Endpoint Security**
	 - Security Baselines
	 - Attack Surface Reduction
	 - Account Protection
 - **Reports**
	 - Endpoint Analytics
		 - Proactive Remediations
> WARNING! These policies will break certain legacy applications that rely on unsecure practices, such as using LDAP (instead of LDAPS), Basic Authentication, NTLMv1, or executing JavaScript/Web requests from a PDF or Office file.

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

While the **Devices** and **Endpoint Security** configuration policies are continuously enforced, there are several **Proactive Remediation** scripts that are run on a schedule to fix several misconfigurations.
![Screenshot of Proactive Remediations in the Intune portal.](https://github.com/microsoft/dchemistruck/blob/main/Images/TVM-ProactiveRemediations.png)
- **Adobe DC - Disable Javascript** can be set to run weekly.
- **Set UAC to Automatically Deny Elevation** has a bug with the Intune Policy in my tenant. You can set this to run daily if needed.
- **Fix Unquoted Service Paths** can be set to run weekly.

# Optional Instructions
If you do not have OneDrive or Custom Branding setup yet, make the following changes.

 1. Open the Device Configuration policy for **Windows - Baseline Restrictions** then set the primary domain suffix for use for your tenant.
![Screenshot of how to set the default domain suffix for AADJ devices.](https://github.com/microsoft/dchemistruck/blob/main/Images/TVM-TenantDomain.png)
2. Open the **Device Configuration** policy for **Windows - Baseline Endpoint Protection** then set the fields for your support desk contact information and Login messages.
![Screenshot of setting branding via Intune.](https://github.com/microsoft/dchemistruck/blob/main/Images/TVM-Epp-Branding.png)
![Screenshot of setting the Login Banner via Intune.](https://github.com/microsoft/dchemistruck/blob/main/Images/TVM-Epp-Login.png)
3. To automatically redirect user's Desktop and Documents to OneDrive, first lookup your [Tenant ID](https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/Properties). Then open the **Device Configuration** policy for **Windows - OneDrive and Office Configuration** and set the following two settings.
![Screenshot to silently redirect the Desktop and Documents folder in OneDrive.](https://github.com/microsoft/dchemistruck/blob/main/Images/TVM-OneDrive.png)
![Screenshot to block a user from moving the default folder location for OneDrive.](https://github.com/microsoft/dchemistruck/blob/main/Images/TVM-OneDrive2.png)
