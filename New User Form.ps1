#===========================================================================
# README
#===========================================================================

# This is a script to create a new user written by Tamara Jordan.
# You can configure what settings will be applied to new users below.

#===========================================================================
# CONFIGURATION
#===========================================================================

# The base path where users' home folders are stored
$BaseHomePath = "\\[REDACTED]\users"

# Emali domain name that users should be created with
$DomainName = "[REDACTED].com"

# The drive letter that the user's home folder will be mapped to
$HomeDrive = "Z:"

# The OU where new UK users should be created (LDAP)
$UKou = "OU=[REDACTED],DC=[REDACTED],DC=local"

# The OU where new US users should be created (LDAP)
$USou = "OU=[REDACTED],DC=[REDACTED],DC=local"

# Choose if the user should be forced to change their password at next login
$ChangePasswordAtLogon = $false

# Choose if passwords should never expire
$PasswordNeverExpires = $true

# Whether the user should be enabled or disabled after it gets created
$UserEnabled = $true

# The server on which AD-Connect is installed
$ADConnectSvr = "[REDACTED]"

#===========================================================================
# Hide powershell console at startup (uncomment lines during development)
#===========================================================================

#$t = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
#add-type -name win -member $t -namespace native
#[native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0)

#===========================================================================
# The XAML that controls the look of the GUI
#===========================================================================

# XAML created with Visual Studio 2017
$inputXML = @"
<Window x:Class="NewUser.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:NewUser"
        mc:Ignorable="d"
        Title="New User" Height="335.166" Width="271.536" ResizeMode="CanMinimize">
    <Grid HorizontalAlignment="Left" Width="264">
        <Label Content="First Name" HorizontalAlignment="Left" VerticalAlignment="Top" Height="26" Width="67" Margin="1,6,0,0"/>
        <TextBox x:Name="FirstName" HorizontalAlignment="Left" Height="23" TextWrapping="Wrap" VerticalAlignment="Top" Width="156" Margin="92,10,0,0"/>
        <Label Content="Last Name" HorizontalAlignment="Left" Margin="1,37,0,0" VerticalAlignment="Top" Height="26" Width="68"/>
        <TextBox x:Name="LastName" HorizontalAlignment="Left" Height="23" Margin="92,41,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="156"/>
        <Label Content="Password" HorizontalAlignment="Left" Margin="1,68,0,0" VerticalAlignment="Top" Height="26" Width="68" RenderTransformOrigin="0.655,-0.372"/>
        <TextBox x:Name="Password" HorizontalAlignment="Left" Height="23" Margin="92,72,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="156"/>
        <Label Content="Location" HorizontalAlignment="Left" Margin="1,99,0,0" VerticalAlignment="Top" Height="26" Width="67"/>
        <ComboBox x:Name="Location" HorizontalAlignment="Left" Margin="92,103,0,0" VerticalAlignment="Top" Width="156" Height="22" SelectedIndex="0">
            <ComboBoxItem Content="UK" HorizontalAlignment="Left" Width="154"/>
            <ComboBoxItem Content="US" HorizontalAlignment="Left" Width="154"/>
        </ComboBox>
        <Label Content="Messages:" HorizontalAlignment="Left" Margin="1,130,0,0" VerticalAlignment="Top" Height="26" Width="64"/>
        <TextBox x:Name="Messages" Height="105" Margin="10,161,0,0" TextWrapping="Wrap" VerticalAlignment="Top" HorizontalAlignment="Left" Width="238" IsReadOnly="True" IsReadOnlyCaretVisible="True" Text="Enter a FirstName"/>
        <Button x:Name="CreateBtn" Content="Create User" HorizontalAlignment="Left" Margin="10,271,0,0" VerticalAlignment="Top" Width="238" Height="20"/>
    </Grid>
</Window>
"@

#===========================================================================
# Load XAML Objects In PowerShell
#===========================================================================

# This code is from https://foxdeploy.com/2015/04/16/part-ii-deploying-powershell-guis-in-minutes-using-visual-studio/
$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'

[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {$Form = [Windows.Markup.XamlReader]::Load( $reader )}
catch {Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed."}

$xaml.SelectNodes("//*[@Name]") | % {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name)}

Function Get-FormVariables {
    if ($global:ReadmeDisplay -ne $true) {Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow; $global:ReadmeDisplay = $true}
    write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
    get-variable WPF*
}
# can uncomment this during development
# Get-FormVariables

#===========================================================================
# Functions that get executed after Create User is clicked
#===========================================================================

function AvailableLicenses {
    Invoke-Command -ComputerName $ADConnectSvr -ScriptBlock
    {
        Start-ADSyncSyncCycle -PolicyType Delta
    }
}

function GetEmptyFields {
    # Returns a collection of empty fields, otherwise false
    $emptyFields = @()

    ForEach ($field in $WPFFirstName, $WPFLastName, $WPFPassword) {
        if ($field.Text -eq "") {
            $emptyFields += $field.name
        }
    }

    if ($emptyFields.length -gt 0) {
        return $emptyFields
    }
    else {
        return $false
    }
}

function CreateUser {
    $FirstName = $WPFFirstName.Text
    $LastName = $WPFLastName.Text
    $Password = $WPFPassword.Text

    $DisplayName = "$FirstName $LastName"
    $Username = "${FirstName}.${LastName}"
    $EmailAddress = "${Username}@${DomainName}"
    $ProxyAddress = "SMTP:${EmailAddress}"
    $HomePath = "$BaseHomePath\${Username}"

    if ($WPFLocation.SelectedValue.Content -eq "UK") { $LDAPPath = $UKou}
    elseif ($WPFLocation.SelectedValue.Content -eq "US") { $LDAPPath = $USou}

    New-ADUser `
        -Name $DisplayName `
        -GivenName $FirstName `
        -Surname   $LastName `
        -DisplayName $DisplayName `
        -SamAccountName $Username `
        -UserPrincipalName $EmailAddress `
        -EmailAddress $EmailAddress `
        -path $LDAPPath `
        -ChangePasswordAtLogon $ChangePasswordAtLogon `
        -PasswordNeverExpires $PasswordNeverExpires `
        -HomeDirectory $HomePath `
        -HomeDrive $HomeDrive `
        -Enabled $UserEnabled `
        -AccountPassword (ConvertTo-SecureString -AsPlainText $Password -Force)

    Set-ADUser -identity $Username -Add @{ProxyAddresses = $ProxyAddress}

    $WPFMessages.Text = "User created with the below details`n`n"
    $WPFMessages.Text += "Username: [REDACTED]\$Username`n"
    $WPFMessages.Text += "Email: $EmailAddress`n"
    $WPFMessages.Text += "Password: $Password`n"
}

#===========================================================================
# Define event handlers
#===========================================================================

function Button_Click {
    # Clear any existing messages
    $WPFMessages.Text = ""

    # TODO: Make sure there are available licenses
    $licensesAvailable = AvailableLicenses

    # Verify that there aren't any empty form fields
    $unfilledInput = GetEmptyFields

    if ($unfilledInput -ne $false) {
        $WPFMessages.Text += "You forgot to enter a value in the $unfilledInput field.`n"
    }
    elseif ($licensesAvailable -eq $false) {
        $WPFMessages.Text += "There are no available licenses. Speak with [REDACTED] before doing anything else.`n"
    }
    else { CreateUser }
}

function Update-FormValidation {
    $WPFMessages.Text = "Steps:`n"
    $invalidFields = GetEmptyFields

    if ($invalidFields) {
        $WPFCreateBtn.IsEnabled = $false
        forEach ($fieldName in $invalidFields) {
            $WPFMessages.Text += "Enter a ${fieldName}`n"
        }
    }
    else {
        $WPFCreateBtn.IsEnabled = $true
        $WPFMessages.Text += 'Click "Create User"'
    }
}

#===========================================================================
# Add event handlers
#===========================================================================

# run this once so that the message output is correct and button is disabled
Update-FormValidation

$WPFCreateBtn.Add_Click( {Button_Click} )

forEach ($field in @($WPFFirstName, $WPFLastName, $WPFPassword)) {
    $field.add_TextChanged( { Update-FormValidation })
}

#===========================================================================
# Create the form
#===========================================================================

$Form.ShowDialog() | out-null
