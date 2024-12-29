$recources_main_dir =  Split-Path $PSCommandPath -Parent ;
$sigcheck = "$recources_main_dir\sigcheck64.exe" ;

 Function Select-Folder
        {
            param([string]$Description="Select Folder",[string]$RootFolder="UserProfile")
            do
                {
                
	        

	        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null 
	
	        $objForm = New-Object System.Windows.Forms.FolderBrowserDialog
	        $Description = $text_msg.selectdir ;
	        $objForm.Rootfolder = $RootFolder ;
	        $objForm.Description = $Description ;
	        $Show = $objForm.ShowDialog() ;
		        If ($Show -eq "OK")
			        {
				        Return $objForm.SelectedPath
			        }
		        Else
			        {
				        Write-host "PLEASE SET DIR !!!" -ForegroundColor Red
                        $dir = 0
			        }	
            }while($dir -eq 0)
        }

do
    {
        $input_directory = $null
        $s = $null
        $input_directory = Select-Folder

        Start-Process -NoNewWindow -Wait -FilePath $sigcheck -ArgumentList " -e -s -vrs -vt ""$input_directory"" "
        [string]$s = ($(write-host "DO YOU WANT TO CONTINUE ? WHEN NOT HIT q: " -ForegroundColor yellow -NoNewLine ; Read-Host))

}until($s -eq "q"  )