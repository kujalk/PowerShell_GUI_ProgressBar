Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function GetJobProgress
{
    param($Job)
 
    if($Job.ChildJobs[0].Progress -ne $null)
    {
        $jobProgressHistory = $Job.ChildJobs[0].Progress;
        $latestProgress = $jobProgressHistory[$jobProgressHistory.Count - 1];
        $latestPercentComplete = $latestProgress | Select -expand PercentComplete;
        $latestActivity = $latestProgress | Select -expand Activity;
        $latestStatus = $latestProgress | Select -expand StatusDescription;
       
        return $latestPercentComplete,$latestStatus
    }
}

function Create-Job
{
    param(
        $Job_Name,
        $Do_Exit
    )
    $job = Start-Job -Name $Job_Name -Scriptblock {
    
        Write-Progress -Activity $using:Job_Name  -Status "Copied Patches" -PercentComplete 25; Start-Sleep (Get-Random -Maximum 10)
        Write-Progress -Activity $using:Job_Name  -Status "Installed Patches" -PercentComplete 50; Start-Sleep (Get-Random -Maximum 10)
        
        if($using:Do_Exit)
        {
            exit 1
        }
        Write-Progress -Activity $using:Job_Name  -Status "Rebooting Done" -PercentComplete 75; Start-Sleep (Get-Random -Maximum 10)
        Write-Progress -Activity $using:Job_Name  -Status "Validated Patches" -PercentComplete 100; Start-Sleep (Get-Random -Maximum 10)
    }

    return $job
}

function Create-ProgressBar{
    param(
        $Form_Name,
        $Label_Name,
        $Label_Top
    )

        # create label
        $label1 = New-Object system.Windows.Forms.Label
        $label1.Text = $Label_Name
        $label1.Left=5
        $label1.Top= $Label_Top
        $label1.Width= 480
        $label1.Height=15
        $label1.Font= "Verdana"
    
        #add the label to the form
        $Form_Name.controls.add($label1)
    
        $progressBar1 = New-Object System.Windows.Forms.ProgressBar
        $progressBar1.Name = $Label_Name
        $progressBar1.Value = 0
        $progressBar1.Style="Continuous"
    
        $System_Drawing_Size = New-Object System.Drawing.Size
        $System_Drawing_Size.Width = 460
        $System_Drawing_Size.Height = 20
        $progressBar1.Size = $System_Drawing_Size
        $progressBar1.ForeColor = "Green"
    
        $form1.Topmost = $true
    
        $progressBar1.Left = 5
        $progressBar1.Top = ($Label_Top + 20)
        $Form_Name.Controls.Add($progressBar1)

        return $progressBar1,$label1

}
#Form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Patching DCs'
$form.Size = New-Object System.Drawing.Size(300,200)
$form.StartPosition = 'CenterScreen'
$Form.AutoScroll = $True
$Form.AutoSize = $True

#OK Button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(75,300)
$okButton.Size = New-Object System.Drawing.Size(75,23)
$okButton.Text = 'OK'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

#Cancel Button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(150,300)
$cancelButton.Size = New-Object System.Drawing.Size(75,23)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

#Label
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10,20)
$label.Size = New-Object System.Drawing.Size(280,20)
$label.Text = 'Please enter the information in the DCs below:'
$form.Controls.Add($label)


$textBox = New-Object System.Windows.Forms.TextBox 
$textBox.Location = New-Object System.Drawing.Size(10,40) 
$textBox.Size = New-Object System.Drawing.Size(260,150)
$textBox.AcceptsReturn = $true
$textBox.AcceptsTab = $false
$textBox.Multiline = $true
$textBox.ScrollBars = 'Both'
$textBox.Text = "Input DCs Name"
$form.Controls.Add($textBox)

$form.Topmost = $true

$form.Add_Shown({$textBox.Select()})
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK)
{
    Write-Host $result
    $form.Hide()

    #create the form
    $form1 = New-Object System.Windows.Forms.Form
    $form1.Text = 'Patching DCs'
    $form1.Size = New-Object System.Drawing.Size(300,500)
    $form1.StartPosition = 'CenterScreen'
    $Form1.AutoScroll = $True
    $Form1.AutoSize = $True


    $form1.Show()

    $All_DCs = $textBox.Text.split("`n")

    $Temp=@()
    $Top_Initial = 10

    $Count=0

    foreach($DC in $All_DCs)
    {
        Write-Host "Server - $DC"

        if($Count -eq 0)
        {
            $Temp += Create-ProgressBar -Form_Name $form1 -Label_Name $DC -Label_Top $Top_Initial
        }
        else 
        {
            $Top_Initial=$Top_Initial+40
            $Temp += Create-ProgressBar -Form_Name $form1 -Label_Name $DC -Label_Top $Top_Initial
        }

        $Count++

    }
    
Start-Sleep 2

#Create Jobs
$Job=@()
$simulate_exit=0
foreach ($DC in $All_DCs)
{

    if(($simulate_exit -eq 1) -or ($simulate_exit -eq 2))
    {
        $Job+=Create-Job -Job_Name $DC -Do_Exit $True
        Write-Host "Created exit job"
    }
    else 
    {
        $Job+=Create-Job -Job_Name $DC -Do_Exit $False    
    }

    $simulate_exit+=1
}

Start-Sleep 5

while((Get-Job | Where-Object {$_.State -ne "Completed"}).Count -gt 0)
{    
    $a=0

    foreach ($J in $Job)
    {
        $Percent_And_Status=GetJobProgress($J)
        
        $Temp[($a*2)].Value=$Percent_And_Status[0]
        $Temp[($a*2)+1].Text="$($All_DCs[$a]) - "+$Percent_And_Status[1]
        $Temp[($a*2)+1].Refresh()
        
        $a++
    }

    Start-Sleep 1
    
}

 

#Ask user confirmation after user Input DCs

#Check any % is < 100 after all jobs completed and mark them as red. Should be moved within while loop
#job get hidden after some time. Therefore check for job completion status
$b=0
foreach ($J in $Job)
{
    $Percent_And_Status=GetJobProgress($J)
    
    if($Percent_And_Status[0] -lt 100)
    {
        Write-Host "Found"
        $Temp[($b*2)].ForeColor="Red"
    } 
    
    $b++
}
#Only get the triggered jobs

    #last to enable close button
    $form1.Hide()
    $form1.ShowDialog()

}

