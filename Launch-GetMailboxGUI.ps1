$Version = "1"
#region FUNCTIONS other than Form events
Function IsPSV3 {
    <#
    .DESCRIPTION
    Just printing Powershell version and returning "true" if powershell version
    is Powershell v3 or more recent, and "false" if it's version 2.
    .OUTPUTS
    Returns $true or $false
    .EXAMPLE
    IsPSVersionV3
    #>
    $PowerShellMajorVersion = $PSVersionTable.PSVersion.Major
    $msgPowershellMajorVersion = "You're running Powershell v$PowerShellMajorVersion"
    Write-Host $msgPowershellMajorVersion -BackgroundColor blue -ForegroundColor yellow
    If($PowerShellMajorVersion -le 2){
        Write-Host "Sorry, PowerShell v3 or more is required. Exiting."
        Return $false
        Exit
    } Else {
        Write-Host "You have PowerShell v3 or later, great !" -BackgroundColor blue -ForegroundColor yellow
        Return $true
        }
}

Function Test-ExchTools(){
    <#
    .SYNOPSIS
    This small function will just check if you have Exchange tools installed or available on the
    current PowerShell session.

    .DESCRIPTION
    The presence of Exchange tools are checked by trying to execute "Get-ExBanner", one of the basic Exchange
    cmdlets that runs when the Exchange Management Shell is called.

    Just use Test-ExchTools in your script to make the script exit if not launched from an Exchange
    tools PowerShell session...

    .EXAMPLE
    Test-ExchTools
    => will exit the script/program si Exchange tools are not installed
    #>
    Try
    {
        Get-command Get-MAilbox -ErrorAction Stop
        $ExchInstalledStatus = $true
        $Message = "Exchange tools are present !"
        Write-Host $Message -ForegroundColor Blue -BackgroundColor Red
    }
    Catch [System.SystemException]
    {
        $ExchInstalledStatus = $false
        $Message = "Exchange Tools are not present ! This script/tool need these. Exiting..."
        Write-Host $Message -ForegroundColor red -BackgroundColor Blue
        # Add-Type -AssemblyName presentationframework, presentationcore
        # Option #4 - a message, a title, buttons, and an icon
        # More info : https://msdn.microsoft.com/en-us/library/system.windows.messageboximage.aspx
        $msg = "You must run this tool from an Exchange-enabled PowerShell console like Exchange Management Console or a PowerShell session where you imported an Exchange session."
        $Title = "Error - No Exchange Tools available !"
        $Button = "Ok"
        $Icon = "Error"
        [System.Windows.MessageBox]::Show($msg,$Title, $Button, $icon)
        Exit
    }
    Return $ExchInstalledStatus
}

Function Run-Action{
    $SelectedAction = $wpf.comboSelectAction.SelectedItem.Content
    Switch ($SelectedAction) {
        "Disable Mailbox"  {
            Write-host "Displaying Info"
            Write-Host "Listing selected mailbox names:"
            $SelectedITems = $wpf.GridView.SelectedItems
            $List = @()
            $SelectedItems | Foreach{
                $List += ("""") + $($_.Alias) + ("""")
            }
            $List = $List -join ","
            $Command = "$List | Disable-Mailbox"
            WRite-Host "About to execute action on $($SelectedItems.Count) mailboxes..."
            Write-Host "About to run $Command"
        }
        "List Single Item Recovery status" {
            Write-host "Displaying Mailbox SIR and retention settings status"
            $SelectedITems = $wpf.GridView.SelectedItems
            Write-host "Displaying Mailbox Single Item Recovery and retention settings status for $($SelectedItems.count) items..."
            $List = @()
            $SelectedItems | Foreach {
                $List += $_.primarySMTPAddress.tostring()
            }
            #$List = $List -join ","
            Function Get-MailboxSIRView {
                [CmdLetBinding()]
                Param(
                    [Parameter(Mandatory = $False, Position = 1)][string[]]$List
                )
                #Initiating stopwatch to measure the time it takes to retrieve mailboxes
                $stopwatch = [system.diagnostics.stopwatch]::StartNew()

                $QueryMailboxFeatures = $List | Get-Mailbox | Select DisplayName, *item*
                [System.Collections.IENumerable]$MailboxFeatures = @($QueryMailboxFeatures)
                Write-host $($MailboxFeatures | ft | out-string)
                
                #Stopping stopwatch
                $stopwatch.Stop()
                $msg = "`n`nInstruction took $([math]::round($($StopWatch.Elapsed.TotalSeconds),2)) seconds to retrieve $($Mailboxes.count) mailboxes..."
                Write-Host $msg
                $msg = $null
                $StopWatch = $null

                #region Get-MailboxFeaturesView Form definition
                # Load a WPF GUI from a XAML file build with Visual Studio
                Add-Type -AssemblyName presentationframework, presentationcore
                $wpf = @{ }
                # NOTE: Either load from a XAML file or paste the XAML file content in a "Here String"
                #$inputXML = Get-Content -Path ".\WPFGUIinTenLines\MainWindow.xaml"
                $inputXML = @"
                <Window x:Name="frmMbxSIRStatus" x:Class="Get_CASMAilboxFeaturesWPF.MainWindow"
                                        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                                        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
                                        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
                                        xmlns:local="clr-namespace:Get_CASMAilboxFeaturesWPF"
                                        mc:Ignorable="d"
                                        Title="Mailboxes Single Item Recovery and Retention settings status" Height="437.024" Width="872.145" ResizeMode="NoResize">
                    <Grid>
                        <DataGrid x:Name="DataGridCASMbx" HorizontalAlignment="Left" Height="326" Margin="10,10,-59,0" VerticalAlignment="Top" Width="844" IsReadOnly="True"/>
                        <Button x:Name="btnClose" Content="Close" HorizontalAlignment="Left" Margin="748,352,0,0" VerticalAlignment="Top" Width="106" Height="46"/>
                        <Button x:Name="btnClipboard" Content="Copy to clipboard" HorizontalAlignment="Left" Margin="10,352,0,0" VerticalAlignment="Top" Width="174" Height="46"/>

                    </Grid>
                </Window>   
"@

                $inputXMLClean = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace 'x:Class=".*?"','' -replace 'd:DesignHeight="\d*?"','' -replace 'd:DesignWidth="\d*?"',''
                [xml]$xaml = $inputXMLClean
                $reader = New-Object System.Xml.XmlNodeReader $xaml
                $tempform = [Windows.Markup.XamlReader]::Load($reader)
                $namedNodes = $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")
                $namedNodes | ForEach-Object {$wpf.Add($_.Name, $tempform.FindName($_.Name))}

                #Get the form name to be used as parameter in functions external to form...
                $FormName = $NamedNodes[0].Name


                #Define events functions
                #region Load, Draw (render) and closing form events
                #Things to load when the WPF form is loaded aka in memory
                $wpf.$FormName.Add_Loaded({
                    #Update-Cmd
                    $wpf.DataGridCASMbx.ItemsSource = $MailboxFeatures
                })
                #Things to load when the WPF form is rendered aka drawn on screen
                $wpf.$FormName.Add_ContentRendered({
                    #Update-Cmd
                })
                $wpf.$FormName.add_Closing({
                    $msg = "Closed the MBX SIR and retention settings status list window"
                    write-host $msg
                })
                $wpf.btnClipboard.add_Click({
                    $CSVClip = $mailboxFeatures | ConvertTo-CSV -NoTypeInformation
                    $CSVClip | clip.exe
                    $title = "Copied !"
                    $msg = "Data copied to the clipboard ! `n`rUse CTRL+V on Notepad or on Excel !"
                    [System.Windows.MessageBox]::Show($msg,$title, "OK","Asterisk")
                })
                $wpf.btnClose.add_Click({
                    $wpf.$FormName.Close()
                })

                #endregion Load, Draw and closing form events
                #End of load, draw and closing form events

                #HINT: to update progress bar and/or label during WPF Form treatment, add the following:
                # ... to re-draw the form and then show updated controls in realtime ...
                $wpf.$FormName.Dispatcher.Invoke("Render",[action][scriptblock]{})


                # Load the form:
                # Older way >>>>> $wpf.MyFormName.ShowDialog() | Out-Null >>>>> generates crash if run multiple times
                # Newer way >>>>> avoiding crashes after a couple of launches in PowerShell...
                # USing method from https://gist.github.com/altrive/6227237 to avoid crashing Powershell after we re-run the script after some inactivity time or if we run it several times consecutively...
                $async = $wpf.$FormName.Dispatcher.InvokeAsync({
                    $wpf.$FormName.ShowDialog() | Out-Null
                })
                $async.Wait() | Out-Null

                #endregion
                # end of Form definition for Get-MailboxFeaturesView
                
            }

            Get-MailboxSIRView $List            
        }
        "List Mailbox Features"  {
            Write-host "Displaying Mailbox Features"
            $SelectedITems = $wpf.GridView.SelectedItems
            Write-host "Displaying Mailbox Features for $($SelectedItems.count) items..."
            $List = @()
            $SelectedItems | Foreach {
                $List += $_.primarySMTPAddress.tostring()
            }
            #$List = $List -join ","
            Function Get-MailboxFeaturesView {
                [CmdLetBinding()]
                Param(
                    [Parameter(Mandatory = $False, Position = 1)][string[]]$List
                )

                #Initiating stopwatch to measure the time it takes to retrieve mailboxes
                $stopwatch = [system.diagnostics.stopwatch]::StartNew()

                $QueryMailboxFeatures = $List | Get-CASMAilbox | Select DisplayName, *enabled, *MAPIblock*
                [System.Collections.IENumerable]$MailboxFeatures = @($QueryMailboxFeatures)
                Write-host $($MailboxFeatures | ft DisplayName, ActiveSyncEnabled,OWAEnabled,ECPEnabled,MAPIEnabled,MAPIBlockOutlookRpcHttp,MapiHttpEnabled  -a | out-string)

                #Stopping stopwatch
                $stopwatch.Stop()
                $msg = "`n`nInstruction took $([math]::round($($StopWatch.Elapsed.TotalSeconds),2)) seconds to retrieve $($Mailboxes.count) mailboxes..."
                Write-Host $msg
                $msg = $null
                $StopWatch = $null

                #region Get-MailboxFeaturesView Form definition
                # Load a WPF GUI from a XAML file build with Visual Studio
                Add-Type -AssemblyName presentationframework, presentationcore
                $wpf = @{ }
                # NOTE: Either load from a XAML file or paste the XAML file content in a "Here String"
                #$inputXML = Get-Content -Path ".\WPFGUIinTenLines\MainWindow.xaml"
                $inputXML = @"
                <Window x:Name="frmCASMBOXProps" x:Class="Get_CASMAilboxFeaturesWPF.MainWindow"
                                        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                                        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
                                        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
                                        xmlns:local="clr-namespace:Get_CASMAilboxFeaturesWPF"
                                        mc:Ignorable="d"
                                        Title="Mailbox features enabled and blocked status" Height="437.024" Width="872.145" ResizeMode="NoResize">
                    <Grid>
                        <DataGrid x:Name="DataGridCASMbx" HorizontalAlignment="Left" Height="326" Margin="10,10,-59,0" VerticalAlignment="Top" Width="844" IsReadOnly="True"/>
                        <Button x:Name="btnClose" Content="Close" HorizontalAlignment="Left" Margin="748,352,0,0" VerticalAlignment="Top" Width="106" Height="46"/>
                        <Button x:Name="btnClipboard" Content="Copy to clipboard" HorizontalAlignment="Left" Margin="10,352,0,0" VerticalAlignment="Top" Width="174" Height="46"/>

                    </Grid>
                </Window>         
"@

                $inputXMLClean = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace 'x:Class=".*?"','' -replace 'd:DesignHeight="\d*?"','' -replace 'd:DesignWidth="\d*?"',''
                [xml]$xaml = $inputXMLClean
                $reader = New-Object System.Xml.XmlNodeReader $xaml
                $tempform = [Windows.Markup.XamlReader]::Load($reader)
                $namedNodes = $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")
                $namedNodes | ForEach-Object {$wpf.Add($_.Name, $tempform.FindName($_.Name))}

                #Get the form name to be used as parameter in functions external to form...
                $FormName = $NamedNodes[0].Name

                #Define events functions
                #region Load, Draw (render) and closing form events
                #Things to load when the WPF form is loaded aka in memory
                $wpf.$FormName.Add_Loaded({
                    #Update-Cmd
                    $wpf.DataGridCASMbx.ItemsSource = $MailboxFeatures
                })
                #Things to load when the WPF form is rendered aka drawn on screen
                $wpf.$FormName.Add_ContentRendered({
                    #Update-Cmd
                })
                $wpf.$FormName.add_Closing({
                    $msg = "Closed the MBX features list window"
                    write-host $msg
                })
                $wpf.btnClipboard.add_Click({
                    $CSVClip = $mailboxFeatures | ConvertTo-CSV -NoTypeInformation
                    $CSVClip | clip.exe
                    $title = "Copied !"
                    $msg = "Data copied to the clipboard ! `n`rUse CTRL+V on Notepad or on Excel !"
                    [System.Windows.MessageBox]::Show($msg,$title, "OK","Asterisk")
                })
                $wpf.btnClose.add_Click({
                    $wpf.$FormName.Close()
                })

                #endregion Load, Draw and closing form events
                #End of load, draw and closing form events

                #HINT: to update progress bar and/or label during WPF Form treatment, add the following:
                # ... to re-draw the form and then show updated controls in realtime ...
                $wpf.$FormName.Dispatcher.Invoke("Render",[action][scriptblock]{})


                # Load the form:
                # Older way >>>>> $wpf.MyFormName.ShowDialog() | Out-Null >>>>> generates crash if run multiple times
                # Newer way >>>>> avoiding crashes after a couple of launches in PowerShell...
                # USing method from https://gist.github.com/altrive/6227237 to avoid crashing Powershell after we re-run the script after some inactivity time or if we run it several times consecutively...
                $async = $wpf.$FormName.Dispatcher.InvokeAsync({
                    $wpf.$FormName.ShowDialog() | Out-Null
                })
                $async.Wait() | Out-Null

                #endregion
                # end of Form definition for Get-MailboxFeaturesView
                
            }

            Get-MailboxFeaturesView $List
        }
    }
}

Function Update-Label ($msg) {
    $wpf.lblStatus.Content = $msg
    $Wpf.$FormName.Dispatcher.Invoke("Render",[action][scriptblock]{})
}

Function Working-Label {
        # Trick to enable a Label to update during work :
    # Follow with "Dispatcher.Invoke("Render",[action][scriptblobk]{})" or [action][scriptblock]::create({})
    $wpf.$FormName.IsEnabled = $False
    $wpf.lblStatus.Content = "Working ..."
    $wpf.lblStatus.ForeGround = [System.Windows.Media.Brushes]::Red
    $wpf.lblStatus.BackGround = [System.Windows.Media.Brushes]::Blue
    $Wpf.$FormName.Dispatcher.Invoke("Render",[action][scriptblock]{})
}

Function Ready-Label{
    $wpf.$FormName.IsEnabled = $True
    $wpf.lblStatus.Content = "Ready !"
    $wpf.lblStatus.ForeGround = [System.Windows.Media.Brushes]::Green
    $wpf.lblStatus.BackGround = [System.Windows.Media.Brushes]::Yellow
    $Wpf.$FormName.Dispatcher.Invoke("Render",[action][scriptblock]{})
}

Function Update-MainCommandLine {
    If ($wpf.txtMailboxString.text -eq ""){
        $SearchSubstring = ("*")
    } Else {
        $SearchSubstring = ("*") + ($wpf.txtMailboxString.text) + ("*")
    }
    If ($wpf.chkUnlimited.IsChecked){
        $ResultSize = "Unlimited"
    } Else {
        $ResultSize = $wpf.txtResultSize.Text
    }
    $chkIncludeDiscovery = $false
    If ($chkIncludeDiscovery){
        $commandLine = "Get-Mailbox -ResultSize $ResultSize -Identity $SearchSubstring -ErrorAction Stop | Select Name,Alias,DisplayName,primarySMTPAddress"
    } Else {
        $commandLine = "Get-Mailbox -ResultSize $ResultSize -Identity $SearchSubstring -Filter {RecipientTypeDetails -ne `"DiscoveryMailbox`"} -ErrorAction Stop | Select Name,Alias,DisplayName,primarySMTPAddress"
    }
    $wpf.txtMainCommand.Text = $CommandLine
}
Function Get-Mailboxes {
    If ($([int]$wpf.txtResultSize.Text) -gt 1000) {Write-Host "$($wpf.txtResultSize.Text) is greater than 1000 ..."} Else {write-host "$($wpf.txtResultSize.Text) is less than 1000"}
    If ($([int]$wpf.txtResultSize.Text) -gt 1000 -or $wpf.chkUnlimited.IsChecked){
        # Option #4 - a message, a title, buttons, and an icon
        # More info : https://msdn.microsoft.com/en-us/library/system.windows.messageboximage.aspx
        if ($wpf.chkUnlimited.IsChecked) {
            $Specified = $wpf.chkUnlimited.Content
        } Else {
            $Specified = "$($wpf.txtResultSize.Text), which is more than 1000"
        }
        $msg = "WARNING: You specified -> $Specified <- for the Resultsize, mailbox collection can take a LOT of time, Continue ? (Y/N)"
        $Title = "Question..."
        $Button = "YesNo"
        $Icon = "Question"
        $Answer = [System.Windows.MessageBox]::Show($msg,$Title, $Button, $icon)
        If($Answer -eq "No"){Return}
    }
    Try {
        #Initiating stopwatch to measure the time it takes to retrieve mailboxes
        $stopwatch = [system.diagnostics.stopwatch]::StartNew()
        #Getting the command line from the text box where it's generated
        $commandLine = $wpf.txtMainCommand.text
        #Invoking the command line and storing in a variable
        $Mailboxes = invoke-expression $CommandLine
        #Stopping stopwatch
        $stopwatch.Stop()
        $msg = "`n`nInstruction took $([math]::round($($StopWatch.Elapsed.TotalSeconds),2)) seconds to retrieve $($Mailboxes.count) mailboxes..."
        Write-Host $msg
        $msg = $null
        $StopWatch = $null

        #Populating the GridView
        [System.Collections.IENumerable]$Results = @($Mailboxes)
        $wpf.GridView.ItemsSource = $Results
        $wpf.GridView.Columns | Foreach {
            $_.CanUserSort = $true
        }
        $wpf.lblNbItemsInGrid.Content = $($Results.Count)
    } Catch {
        $Mailboxes = $null
        $wpf.GridView.ItemsSource = $null
        write-host "ZERO MAILBOXES"
        $wpf.lblNbItemsInGrid.Content = 0
    }
}

#endregion

#========================================================
#region WPF form definition and load controls
#========================================================

# Load a WPF GUI from a XAML file build with Visual Studio
Add-Type -AssemblyName presentationframework, presentationcore
$wpf = @{}
# NOTE: Either load from a XAML file or paste the XAML file content in a "Here String"
# $inputXML = Get-Content -Path "C:\Users\Kamehameha\Documents\GitHub\PowerShell\Get-EventsFromEventLog\VisualStudio2017WPFDesign\Launch-EventsCollector-WPF\Launch-EventsCollector-WPF\MainWindow.xaml"
$inputXML = @"
<Window x:Name="WForm" x:Class="GridView_WPF.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:GridView_WPF"
        mc:Ignorable="d"
        Title="Search Mailboxes" Height="535.64" Width="800" ResizeMode="NoResize">
    <Grid>
        <DataGrid x:Name="GridView" HorizontalAlignment="Left" Height="385" Margin="353,10,0,0" VerticalAlignment="Top" Width="410"/>
        <TextBox x:Name="txtMailboxString" HorizontalAlignment="Left" Height="23" Margin="10,67,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="338"/>
        <Label Content="Search for mailbox (substring of alias, e-mail address, &#xD;&#xA;display name, ...)" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,11,0,0" Height="51" Width="302"/>
        <Button x:Name="btnRun" Content="Search" HorizontalAlignment="Left" Margin="10,95,0,0" VerticalAlignment="Top" Width="75" Height="32">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <Label x:Name="lblStatus" Content="Please start a search..." HorizontalAlignment="Left" VerticalAlignment="Top" Margin="0,471,0,0" Width="784" FontStyle="Italic" FontWeight="Bold">
        </Label>
        <Button x:Name="btnAction" Content="Action on selected" Margin="353,430,250,41" IsEnabled="False">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <ComboBox x:Name="comboSelectAction" HorizontalAlignment="Left" Margin="549,431,0,0" VerticalAlignment="Top" Width="214" Height="35" SelectedIndex="0" IsEnabled="False" TextOptions.TextFormattingMode="Display" VerticalContentAlignment="Center" HorizontalContentAlignment="Center">
            <ComboBox.Effect>
                <DropShadowEffect/>
            </ComboBox.Effect>
            <ComboBoxItem Content="List Mailbox Features"/>
            <ComboBoxItem Content="List Single Item Recovery status"/>
            <ComboBoxItem Content="Disable Mailbox"/>
        </ComboBox>
        <Label x:Name="lblNbItemsInGrid" Content="0" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="506,400,0,0" Width="66"/>
        <Label Content="Number of Items in Grid:" HorizontalAlignment="Left" Margin="353,400,0,0" VerticalAlignment="Top" Width="148"/>
        <Label Content="Selected:" HorizontalAlignment="Left" Margin="591,400,0,0" VerticalAlignment="Top"/>
        <Label x:Name="lblNumberItemsSelected" Content="0" HorizontalAlignment="Left" Margin="650,400,0,0" VerticalAlignment="Top" Width="67"/>
        <TextBox x:Name="txtResultSize" HorizontalAlignment="Left" Height="23" Margin="224,98,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="124" Text="100"/>
        <TextBlock HorizontalAlignment="Left" Margin="95,95,0,0" TextWrapping="Wrap" Text="ResultSize (aka Nb of mailboxes to display):" VerticalAlignment="Top" Width="124"/>
        <Label Content="Status:" HorizontalAlignment="Left" Margin="0,447,0,0" VerticalAlignment="Top"/>
        <TextBox x:Name="txtMainCommand" HorizontalAlignment="Left" Height="132" Margin="10,200,0,0" TextWrapping="Wrap" Text="Get-Mailbox command to be run..." VerticalAlignment="Top" Width="338" IsReadOnly="True"/>
        <Rectangle HorizontalAlignment="Left" Height="26" Margin="353,400,0,0" VerticalAlignment="Top" Width="232">
            <Rectangle.Stroke>
                <SolidColorBrush Color="{DynamicResource {x:Static SystemColors.ActiveBorderColorKey}}"/>
            </Rectangle.Stroke>
        </Rectangle>
        <Rectangle HorizontalAlignment="Left" Height="26" Margin="590,400,0,0" VerticalAlignment="Top" Width="173">
            <Rectangle.Stroke>
                <SolidColorBrush Color="{DynamicResource {x:Static SystemColors.ActiveBorderColorKey}}"/>
            </Rectangle.Stroke>
        </Rectangle>
        <Label Content="The command run when clicking on the Search button is:" HorizontalAlignment="Left" Margin="10,174,0,0" VerticalAlignment="Top" Width="338" FontStyle="Italic"/>
        <CheckBox x:Name="chkUnlimited" Content="Unlimited" HorizontalAlignment="Left" Margin="223,126,0,0" VerticalAlignment="Top"/>

    </Grid>
</Window>
"@

$inputXMLClean = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace 'x:Class=".*?"','' -replace 'd:DesignHeight="\d*?"','' -replace 'd:DesignWidth="\d*?"',''
[xml]$xaml = $inputXMLClean
$reader = New-Object System.Xml.XmlNodeReader $xaml
$tempform = [Windows.Markup.XamlReader]::Load($reader)
$namedNodes = $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")
$namedNodes | ForEach-Object {$wpf.Add($_.Name, $tempform.FindName($_.Name))}

#Get the form name to be used as parameter in functions external to form...
$FormName = $NamedNodes[0].Name

#========================================================
# END of WPF form definition and load controls
#endregion
#========================================================

#========================================================
#region WPF EVENTS definition
#========================================================

#region Buttons
$wpf.btnRun.add_Click({
    Working-Label
    Get-Mailboxes
    Ready-Label
})

$wpf.btnAction.add_Click({
    Working-Label
    Run-Action
    Ready-Label
})
# End of Buttons region
#endregion

#region Load, Draw (render) and closing form events
#Things to load when the WPF form is loaded aka in memory
$Wpf.$FormName.Add_Loaded({
    Ready-Label
    Update-MainCommandLine
})
#Things to load when the WPF form is rendered aka drawn on screen
$Wpf.$FormName.Add_ContentRendered({

})
$Wpf.$FormName.add_Closing({
    $msg = "bye bye !"
    write-host $msg
})
# End of load, draw and closing form events
#endregion

#region Text Changed events

$wpf.GridView.add_SelectionChanged({
    $Selected = $wpf.GridView.SelectedItems.count
    If ($Selected -eq 0) {
        $wpf.btnAction.IsEnabled = $false
        $wpf.comboSelectAction.IsEnabled = $false
    } ElseIf ($Selected -gt 0) {
        $wpf.btnAction.IsEnabled = $true
        $wpf.comboSelectAction.IsEnabled = $true
    }
    $wpf.lblNumberItemsSelected.Content = $Selected
})

$wpf.txtMailboxString.add_TextChanged({
    Update-MainCommandLine
})

$wpf.txtResultSize.add_TextChanged({
    Update-MainCommandLine
})

$wpf.chkUnlimited.add_Click({
    Update-MainCommandLine
    If ($wpf.chkUnlimited.IsChecked){
        $wpf.txtResultSize.IsEnabled = $false
    } Else {
        $wpf.txtResultSize.IsEnabled = $true
    }
})
#End of Text Changed events
#endregion


#endregion

#=======================================================
#End of Events from the WPF form
#endregion
#=======================================================

IsPSV3 | out-null

Test-ExchTools | out-null

# Load the form:
# Older way >>>>> $wpf.MyFormName.ShowDialog() | Out-Null >>>>> generates crash if run multiple times
# Newer way >>>>> avoiding crashes after a couple of launches in PowerShell...
# USing method from https://gist.github.com/altrive/6227237 to avoid crashing Powershell after we re-run the script after some inactivity time or if we run it several times consecutively...
$async = $wpf.$FormName.Dispatcher.InvokeAsync({
    $wpf.$FormName.ShowDialog() | Out-Null
})
$async.Wait() | Out-Null