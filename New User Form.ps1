#===========================================================================
# README
#===========================================================================

# This is a script to create new users written by Tamara Jordan.
# You can edit the configuration that this script uses by modifying config.json

#===========================================================================
# Hide powershell console at startup (uncomment line in production)
#===========================================================================

function HideConsole {
    $t = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
    add-type -name win -member $t -namespace native
    [native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0)
}

# HideConsole

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
        Title="New User" Height="383.832" Width="326.869" ResizeMode="CanMinimize" Topmost="True">
    <Grid HorizontalAlignment="Left" Width="312">
        <Label Content="First Name" HorizontalAlignment="Left" VerticalAlignment="Top" Height="26" Width="67" Margin="10,6,0,0"/>
        <TextBox x:Name="FirstName" Height="23" TextWrapping="Wrap" VerticalAlignment="Top" Margin="92,10,13,0" Grid.ColumnSpan="2"/>
        <Label Content="Last Name" HorizontalAlignment="Left" Margin="10,37,0,0" VerticalAlignment="Top" Height="26" Width="68"/>
        <TextBox x:Name="LastName" HorizontalAlignment="Left" Height="23" Margin="92,41,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="207" Grid.ColumnSpan="2"/>
        <Label Content="Password" HorizontalAlignment="Left" Margin="10,68,0,0" VerticalAlignment="Top" Height="26" Width="68" RenderTransformOrigin="0.655,-0.372"/>
        <TextBox x:Name="Password" HorizontalAlignment="Left" Height="23" Margin="92,72,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="207" Grid.ColumnSpan="2"/>
        <Label Content="Location" HorizontalAlignment="Left" Margin="10,101,0,0" VerticalAlignment="Top" Height="26" Width="67"/>
        <ComboBox x:Name="Location" HorizontalAlignment="Left" Margin="92,103,0,0" VerticalAlignment="Top" Width="207" Height="22" SelectedIndex="0" Grid.ColumnSpan="2"/>
        <Label Content="Messages:" HorizontalAlignment="Left" Margin="10,130,0,0" VerticalAlignment="Top" Height="26" Width="64"/>
        <TextBox x:Name="Messages" Height="149" Margin="10,161,0,0" TextWrapping="Wrap" VerticalAlignment="Top" HorizontalAlignment="Left" Width="289" IsReadOnly="True" IsReadOnlyCaretVisible="True" Grid.ColumnSpan="2"/>
        <Button x:Name="CreateBtn" Content="Create User" HorizontalAlignment="Left" Margin="10,315,0,0" VerticalAlignment="Top" Width="289" Height="20" Grid.ColumnSpan="2"/>
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

$xaml.SelectNodes("//*[@Name]") | ForEach-Object {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name)}

Function Get-FormVariables {
    if ($global:ReadmeDisplay -ne $true) {Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow; $global:ReadmeDisplay = $true}
    write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
    get-variable WPF*
}
# can uncomment this during development
# Get-FormVariables

#===========================================================================
# Functions for user creation
#===========================================================================

function Add-NewUser {
    $FirstName = $WPFFirstName.Text
    $LastName = $WPFLastName.Text
    $Password = $WPFPassword.Text

    $DisplayName = "$FirstName $LastName"
    $Username = "${FirstName}.${LastName}"
    $EmailAddress = "${Username}@$($config.EmailDomain)"
    $ProxyAddress = "SMTP:${EmailAddress}"
    $HomePath = "$($config.HomePathBase)\${Username}"
    $LDAPPath = $config.Locations.($WPFLocation.SelectedValue)

    New-ADUser `
        -Name $DisplayName `
        -GivenName $FirstName `
        -Surname   $LastName `
        -DisplayName $DisplayName `
        -SamAccountName $Username `
        -UserPrincipalName $EmailAddress `
        -EmailAddress $EmailAddress `
        -path $LDAPPath `
        -ChangePasswordAtLogon $config.UserSettings.ChangePasswordAtNextLogon `
        -PasswordNeverExpires $config.UserSettings.PasswordNeverExpires `
        -HomeDirectory $HomePath `
        -HomeDrive "$($config.HomeDriveLetter):" `
        -Enabled $config.UserSettings.UserIsEnabled `
        -AccountPassword (ConvertTo-SecureString -AsPlainText $Password -Force)

    Set-ADUser -identity $Username -Add @{ProxyAddresses = $ProxyAddress}

    $WPFMessages.Text = "User created with the below details`n`n"
    $WPFMessages.Text += "Username: $($config.ADDomain)\$Username`n"
    $WPFMessages.Text += "Email: $EmailAddress`n"
    $WPFMessages.Text += "Password: $Password`n"
}

function Sync-ADConnectTo365 {
    Invoke-Command -ComputerName $config.ADConnectServer -ScriptBlock {
        start-adsyncsynccycle -PolicyType Delta
    }
    $WPFMessages.Text += "`nREMEMBER: You still need to license the user and add them to any required security/distribution groups"
}

#===========================================================================
# Event handlers
#===========================================================================

function Button_Click {
    $WPFMessages.Foreground = "black"
    $WPFMessages.Text = "Please wait..."
    DisableAll
    $errorMessage = ""

    try {
        Add-NewUser
    }
    catch {
        $errorMessage = $_.Exception.Message
    }
    finally {
        if ($errorMessage -eq "") {
            $WPFMessages.Foreground = "green"
            Sync-ADConnectTo365
        }
        else {
            $WPFMessages.Text = "User not created. Error details:`n`n$errorMessage"
            $WPFMessages.Foreground = "red"
            $WPFCreateBtn.IsEnabled = $true
            $WPFLocation.IsEnabled = $true
            $WPFFirstName.IsReadOnly = $false
            $WPFLastName.IsReadOnly = $false
            $WPFPassword.IsReadOnly = $false
        }
    }
}

function Update-FormValidation {
    # $WPFMessages.Text = "Steps:`n"
    $WPFMessages.Text = ""
    $hasError = $false

    # show errors if firstname or lastname are empty, or have symbols in them
    forEach ($field in @($WPFFirstName, $WPFLastName)) {
        if ($field.Text.length -eq 0) {
            $hasError = $true
            $WPFMessages.Text += "Please enter a $($field.name)`n"
        }
        elseif ($field.Text -match "[^a-zA-Z0-9]+") {
            $hasError = $true
            $WPFMessages.Text += "$($field.name) cannot contain symbols`n"
        }
    }

    # show an error if the chosen location is blank
    if ($WPFLocation.SelectedValue -eq "") {
        $hasError = $true
        $WPFMessages.Text += "Please select a Location`n"
    }

    # if the password box isn't empty, show validation errors when applicable
    $passwordErrors = GetPasswordErrors

    if ($WPFPassword.Text.length -eq 0) {
        $hasError = $true
        $WPFMessages.Text += "Please enter a Password`n"
    }
    elseif ($passwordErrors.length -gt 0) {
        $hasError = $true
        forEach ($passwordError in $passwordErrors) {
            $WPFMessages.Text += "$passwordError`n"
        }
    }

    if ($hasError) {
        $WPFMessages.Foreground = "red"
        $WPFCreateBtn.IsEnabled = $false
    }
    else {
        $WPFCreateBtn.IsEnabled = $true
        $WPFMessages.Foreground = "black"
        $WPFMessages.Text += 'Click "Create User"'
    }
}

#===========================================================================
# Other functions
#===========================================================================

function DisableAll {
    $WPFCreateBtn.IsEnabled = $false
    $WPFLocation.IsEnabled = $false
    $WPFFirstName.IsReadOnly = $true
    $WPFLastName.IsReadOnly = $true
    $WPFPassword.IsReadOnly = $true
}

function InitialiseFormElements {
    # Add a default location
    $WPFLocation.Items.add("") | Out-Null

    # Add the locations from the config file
    foreach ($location in $config.Locations.psobject.properties) {
        $WPFLocation.Items.add($location.Name) | out-null
    }

    # Useful when there are long errors
    $WPFMessages.VerticalScrollBarVisibility = "auto"
}

function AddEventHandlers {
    $WPFLocation.Add_SelectionChanged( { Update-FormValidation })

    forEach ($field in @($WPFFirstName, $WPFLastName, $WPFPassword)) {
        $field.add_TextChanged( { Update-FormValidation } )
    }

    $WPFCreateBtn.Add_Click( {Button_Click} )

    # run this once so that the message output is correct and button is disabled
    Update-FormValidation
}

function GetPasswordErrors {
    $errors = @()
    $pwLength = $WPFPassword.Text.length

    if ($pwLength -lt 8) {$errors += "Password needs $(8 - $pwLength) more characters"}
    if ($WPFPassword.Text -match "^[^0-9]+$") {$errors += "Password needs 1 number"}
    if ($WPFPassword.Text -match "^[a-zA-Z0-9]+$") {$errors += "Password needs 1 symbol"}
    if ($WPFPassword.Text -cmatch "^[^A-Z]+$") {$errors += "Password needs 1 uppercase letter"}
    if ($WPFPassword.Text -cmatch "^[^a-z]+$") {$errors += "Password needs 1 lowercase letter"}

    return $errors
}

#===========================================================================
# Configuration
#===========================================================================

try {
    $config = Get-Content ".\config.json" -ErrorAction "stop" | ConvertFrom-Json
    $configError = $false
}
catch [System.Management.Automation.ItemNotFoundException] {
    $WPFMessages.Text = $_.Exception.Message
    $WPFMessages.Text += "`n`nYou probably forgot to rename config.example.json to config.json"
    $configError = $true
}
catch [System.ArgumentException] {
    $WPFMessages.Text = "Your config.json contains invalid syntax. Did you remember to remove the comments?"
    $WPFMessages.Text += "`n`n$($_.Exception.Message)"
    $configError = $true
}
finally {
    if ($configError) {
        $WPFMessages.Foreground = "red"
        DisableAll
    }
    else {
        InitialiseFormElements
        AddEventHandlers
    }
}

#===========================================================================
# Show the form :)
#===========================================================================

$Form.ShowDialog() | out-null
