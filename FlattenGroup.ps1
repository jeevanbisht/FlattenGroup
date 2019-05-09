
 <# 
 
.SYNOPSIS
	UserAttribute.ps1 is a Windows PowerShell script to expand a group by 1 Level and apply values to the ExtensionAttribute1.
.DESCRIPTION
	Version: 1.0.0
	UserAttribute.ps1s1 is a Windows PowerShell script to  expand a group by 1 Level and apply values to the ExtensionAttribute1.
    This can then furhter be used to create Dynamic Groups in the Azure AD, this helps in flattening the nested group on prem to be used in Azure AD.

    
.DISCLAIMER
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
	THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.
#> 


 #Measure-command {
 #=======================================================================================================
 #Master Config
 
 # This is where all the output files will be processed.
 $AppBaseFolder = "c:\temp"

 # Settings this value to  $true will not make any changes but allow you to assess the change/performance.
 # The summary and error report will provide you the list of the applicable changes.
 $ReadOnlyMode=$true
 
 # Below value incidates the safe number of objects that are allowed to be processed.
 $ChangeCountThreshold=5
 
 
 
 #=======================================================================================================
 
 #This is the group that will be expanded.
 $Group="GroupName"

 # This is the value of the Attribute to be updated
 $SKU="EMSE3-O365E5"

 #Email Subject, might be altered in this script based on conditions.
 $Subject="License Assignment Report - $SKU  "
 #=======================================================================================================
   
  
  $UsersObjectList =  [System.Collections.ArrayList]@();
  $ChildGroupsList=  [System.Collections.ArrayList]@();


  ## Find all Users and Group in the Top group specified  
 $ParentGroupMembersList=Get-ADGroup -Identity $Group -Properties members


 ## Seperate Users and Groups
 foreach ($ParentGroupMembersListItem in $ParentGroupMembersList.members)
 {
    $ParentGroupMembersListItemObject = Get-ADObject -Identity $ParentGroupMembersListItem 
    
    if( $ParentGroupMembersListItemObject.ObjectClass -eq 'group')
    {
        ### This is a subgroup
        $ChildGroupsList.Add($ParentGroupMembersListItemObject.DistinguishedName)
        
    }
    if( $ParentGroupMembersListItemObject.ObjectClass -eq 'user')
    {

        ### This is a user in the Parent Group.
        ### Get a corresponding ADUserObject with Appropriate Attributes and Add to master UsersObjectList
        $UsersObjectList.add( (Get-ADUser $ParentGroupMembersListItemObject.DistinguishedName -Properties name,extensionAttribute1))
     }

 }
 
 foreach ($ChildGroupsListItem in $ChildGroupsList)
 {
    ## Get a corresponding Group Object, these are small in number
    $ChildGroupObject=get-adgroup -Identity $ChildGroupsListItem
    ## Get the Group Memebers
    $ChildGroupMembers=(Get-ADGroup -Filter {Name -eq $ChildGroupObject.Name} -Properties Members | Select Members).Members
    
    foreach($ChildGroupMemberItem in $ChildGroupMembers)
    {

                
        
            ## Thre might be subgroups which will result in error
            ## Option 1: Get adobject call for every object and get objectClass - This might be expensive
            $ChildGroupMemberItemObject = Get-ADObject -Identity $ChildGroupMemberItem 
    
            if( $ChildGroupMemberItemObject.ObjectClass -eq 'group')
            {
                ### This is a subgroup Ignore ( we are only doing 1 level )
                
            }
            elseif( $ChildGroupMemberItemObject.ObjectClass -eq 'user')
            {

                ### This is a user
                ### Get a corresponding ADUserObject with Appropriate Attributes and Add to master UsersObjectList
                $UsersObjectList.add( (Get-ADUser $ChildGroupMemberItemObject.DistinguishedName  -Properties name,extensionAttribute1))
                                
         
            }


            ## Option 2: Ignore the get-aduser errors
            ## Not implemented prone to errors
            ##try
            #{ Get-ADUser $ChildGroupMemberItem -ErrorAction Ignore }
            #catch{}
    }

 }

 
   

 ##### Assess the Impact of changes ###
 $changeCount=0;
 $deltaUsersObjectList =  [System.Collections.ArrayList]@()

  FOREACH( $UsersObjectListItem in $UsersObjectList)
 {
    if ($UsersObjectListItem.extensionAttribute1 -ne $SKU)
    {
        #$UsersObjectListItem.extensionAttribute1
        $changeCount++;
        $deltaUsersObjectList.Add($UsersObjectListItem);
        
    }
    else
    {
       ## Intentionally Left - No action
    }
 } 

 

 ### Delta Users Error Counter
 $deltaUsersObjectChangeErrorCounter=0

 ### Delta Users Update Counter
 $deltaUsersObjectChangeUpdateCounter=0

 ### StatusIndicator
 $BelowThreshold = $false

 $deltaUsersObjectChangeErrorList = [System.Collections.ArrayList]@();
 $deltaUsersObjectChangeList = [System.Collections.ArrayList]@();

 if (($changeCount -le $ChangeCountThreshold) -and ($changeCount -ge 1))
 {
    $BelowThreshold = $true
     
    # deltaUsersObjectList has list of users who SKU dont Match
       
    FOREACH( $deltaUsersObjectListItem in $deltaUsersObjectList)
    {
    
     
     ############# Make Changes ############
     $ExistingSKU=      (Get-ADUser  -Identity $deltaUsersObjectListItem.DistinguishedName  -Properties name,extensionAttribute1 | select extensionAttribute1).extensionAttribute1

     if ($ReadOnlyMode -eq $false)
     {
        ##This will update the extensionAttribute1
        Get-ADUser  -Identity $deltaUsersObjectListItem.DistinguishedName | SET-ADUSER –replace @{extensionAttribute1=$SKU} 
        ## Write-Host  $deltaUsersObjectListItem.Name 
     }


     ############# Verify changes ############
     $UpdatedSKU = (Get-ADUser  -Identity $deltaUsersObjectListItem.DistinguishedName  -Properties name,extensionAttribute1 | select extensionAttribute1).extensionAttribute1
     if ( $SKU -ne     $UpdatedSKU)
     {
        $deltaUsersObjectChangeErrorCounter++
        $deltaUsersObjectChangeErrorListObject = New-Object -TypeName psobject 
        $deltaUsersObjectChangeErrorListObject| Add-Member -MemberType NoteProperty -Name User -Value $deltaUsersObjectListItem.Name
        $deltaUsersObjectChangeErrorListObject| Add-Member -MemberType NoteProperty -Name DN  -Value $deltaUsersObjectListItem.DistinguishedName
        $deltaUsersObjectChangeErrorListObject| Add-Member -MemberType NoteProperty -Name ExistingSKU -Value $ExistingSKU
        $deltaUsersObjectChangeErrorListObject| Add-Member -MemberType NoteProperty -Name NewSKU -Value $SKU
        $deltaUsersObjectChangeErrorList.Add($deltaUsersObjectChangeErrorListObject)
     }
     else
     {
        $deltaUsersObjectChangeUpdateCounter++
        ## Value Updated No action Required
        ## Creating List of Updated users
        $deltaUsersObjectChangeListObject = New-Object -TypeName psobject 
        $deltaUsersObjectChangeListObject| Add-Member -MemberType NoteProperty -Name User -Value $deltaUsersObjectListItem.Name
        $deltaUsersObjectChangeListObject| Add-Member -MemberType NoteProperty -Name DN -Value $deltaUsersObjectListItem.DistinguishedName
        $deltaUsersObjectChangeListObject| Add-Member -MemberType NoteProperty -Name ExistingSKU -Value $ExistingSKU
        $deltaUsersObjectChangeListObject| Add-Member -MemberType NoteProperty -Name NewSKU -Value $SKU
        $deltaUsersObjectChangeList.Add($deltaUsersObjectChangeListObject)
      }
    } 
     
 }
 else
 {
    ## Print Appropriate Messages, Emails are generated accordingly.

    if($ChangeCount -eq 0)
    {
 
        Write-host "$ChangeCount Changes Detected, No Action Performed "
    }
    else
    {
        Write-host "$ChangeCount Changes Detected , Above Threshold $ChangeCountThreshold - Requires Manual Review "
    
    }

 }
 
 
 
 #### Generate Output
 #================================================================================================================= 
   $AppBaseFolder = "c:\temp"
   $OuputFolder=$AppBaseFolder+ "\" +  (Get-Date -UFormat "%Y-%m-%d" )


   $OuputFileName                        ="Delta"+ "-" + (get-date -format HH-mm-ss) + ".htm"
   $deltaUsersObjectChangeErrorOuputFile ="DeltaError"+ "-" + (get-date -format HH-mm-ss) + ".htm"
   $deltaUsersObjectChangeOuputFile      ="DeltaChanges"+ "-" + (get-date -format HH-mm-ss) + ".htm"
   $deltaSummaryFile                     ="Summary"+ "-" + (get-date -format HH-mm-ss) + ".htm"

   $OuputObjectFileName="Delta"+ "-" + (get-date -format HH-mm-ss) + ".xml"


   $OutputPath=$OuputFolder+ "\" + $OuputFileName
   $deltaUsersObjectChangeOuputFilePath=$OuputFolder+ "\" + $deltaUsersObjectChangeOuputFile
   $deltaUsersObjectChangeErrorOuputFilePath=$OuputFolder+ "\" + $deltaUsersObjectChangeErrorOuputFile
   $deltaSummaryFilePath=$OuputFolder+ "\" + $deltaSummaryFile
   

   $ObjectOutputPath=$OuputFolder+ "\" + $OuputObjectFileName
   
   if( (Test-path $OuputFolder) -eq $false )
   {
    New-Item -ItemType Directory -Path $OuputFolder
   }
   


##Make HTML File readable using CSS
   $style = @'
    <style type="text/css">
    table {
    border: 1px solid #000000;
    border-collapse: collapse;
    }
    td {
    font-family: arial, helvetica, sans-serif;
    border: 1px solid #000000;
    padding: 5px;
    }
    </style>
'@



 $deltaUsersSummaryObject = New-Object -TypeName psobject 
 $deltaUsersSummaryObject| Add-Member -MemberType NoteProperty -Name " Delta Changes " -Value  $changeCount
 $deltaUsersSummaryObject| Add-Member -MemberType NoteProperty -Name " Delta Update Failures " -Value $deltaUsersObjectChangeErrorCounter
 $deltaUsersSummaryObject| Add-Member -MemberType NoteProperty -Name " Delta Changes Success " -Value $deltaUsersObjectChangeUpdateCounter
  
 ## This delta file
 $deltaUsersObjectList | Select-Object name,DistinguishedName ,extensionAttribute1 |  ConvertTo-HTML -Title "Change List"  -Head $style  | Out-file $OutputPath
 $deltaUsersObjectList | Export-Clixml $ObjectOutputPath

 ## This delta Change File
 $deltaUsersObjectChangeList |   ConvertTo-HTML -Title "Updated Users" -Head $style | Out-file $deltaUsersObjectChangeOuputFilePath
 
 ## This delta Error  File
 $deltaUsersObjectChangeErrorList |   ConvertTo-HTML  -Title "Error List of  Users"  -Head $style | Out-file $deltaUsersObjectChangeErrorOuputFilePath

 ## This delta Summary File
 $deltaUsersSummaryObject |   ConvertTo-HTML  -Title "Error List of  Users"  -Head $style | Out-file $deltaSummaryFilePath
 #=================================================================================================================

 
 ## SMTP Sections  
 #=================================================================================================================

 # UserName for SMTP
 $username = "user@domain.com"

 # Password for SMTP
 ## To save the initial password use the following command ontime
 ## (Get-Credential).Password | ConvertFrom-SecureString | Out-File "C:\Temp\Password.txt"
 $secureStringPwd =Get-Content "C:\temp\password.txt" | ConvertTo-SecureString  

 # Creds for SMTP
 $creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureStringPwd
 ##

 ## Email Message
 if ($BelowThreshold)
 {   
        # changes within the threshold value  
        $htmlbody = $deltaUsersSummaryObject | ConvertTo-HTML  -Head $style -PreContent "<H2> SKU -$SKU Assignment Report</H2>" | out-string
        Send-MailMessage -To jeevanb@microsoft.com  -From  "identtadmin@identt.onmicrosoft.com" -Subject $Subject -Body $htmlbody -BodyAsHtml -smtpserver smtp.office365.com -usessl -Credential $creds -Port 587  -Attachments $deltaUsersObjectChangeOuputFilePath, $deltaUsersObjectChangeErrorOuputFilePath
    
 }
 else
 {
    if ($changeCount -eq 0)    {
        # if there were no changes detected
        $Subject = " $ChangeCount Changes Detected No Action Required "
        $htmlbody = $deltaUsersSummaryObject | ConvertTo-HTML  -Head $style -PreContent "<H2> SKU -$SKU Assignment Report</H2>" | out-string
        Send-MailMessage -To jeevanb@microsoft.com  -From  "identtadmin@identt.onmicrosoft.com" -Subject $Subject -Body $htmlbody -BodyAsHtml -smtpserver smtp.office365.com -usessl -Credential $creds -Port 587  -Attachments $OutputPath
    }
    else
    {
        # if there were too many changes above the threshold
        $Subject = " Error !! $ChangeCount Changes Detected , Above Threshold $ChangeCountThreshold - Requires Manual Review "
        $htmlbody = $deltaUsersSummaryObject | ConvertTo-HTML  -Head $style -PreContent "<H2> SKU -$SKU Assignment Report</H2>" | out-string
        Send-MailMessage -To jeevanb@microsoft.com  -From  "identtadmin@identt.onmicrosoft.com" -Subject $Subject -Body $htmlbody -BodyAsHtml -smtpserver smtp.office365.com -usessl -Credential $creds -Port 587  -Attachments $OutputPath
    }

 }
 #=================================================================================================================

#} 


  
