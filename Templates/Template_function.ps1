function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description of what the function does
    
    .DESCRIPTION
        Detailed description of the function's functionality and use case
    
    .PARAMETER InputObject
        Description of what the parameter does. Accepts pipeline input.
    
    .PARAMETER ParameterName
        Description of what the parameter does
    
    .PARAMETER Force
        Forces the action without confirmation
    
    .EXAMPLE
        Verb-Noun -ParameterName "value"
        Description of what this example does
    
    .EXAMPLE
        Get-Item *.txt | Verb-Noun -ParameterName "value"
        Description of pipeline usage
    
    .INPUTS
        System.String
        You can pipe strings to this function
    
    .OUTPUTS
        System.Object
        Returns an object with results
    
    .NOTES
        Function Name : Verb-Noun
        Author        : Your name
        Created       : YYYY-MM-DD
        Last Modified : YYYY-MM-DD
        Version       : 1.0
        
    .LINK
        https://docs.microsoft.com/powershell/
    #>
    
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$InputObject,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Option1', 'Option2', 'Option3')]
        [string]$ParameterName = 'Option1',
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    begin {
        Write-Verbose "=== BEGIN: Function starting ==="
        
        try {
            # Initialization and validation
            Write-Verbose "Initializing variables and checking prerequisites"
            
            # --- YOUR INITIALIZATION CODE HERE ---
            
            # Example: Create array for results
            $Results = [System.Collections.Generic.List[PSCustomObject]]::new()
            
            # Example: Check prerequisites
            if ($ParameterName -eq 'Option1') {
                Write-Verbose "Using Option1"
            }
            
            # Example: Counter for statistics
            $ProcessedCount = 0
            $ErrorCount = 0
            
            Write-Verbose "Initialization complete"
        }
        catch {
            Write-Error "Error during initialization: $($_.Exception.Message)"
            throw
        }
    }
    
    process {
        # This block runs once per pipeline object
        
        foreach ($Item in $InputObject) {
            try {
                Write-Verbose "Processing: $Item"
                
                # ShouldProcess provides support for -WhatIf and -Confirm
                if ($PSCmdlet.ShouldProcess($Item, "Perform action")) {
                    
                    # --- YOUR PROCESS CODE HERE ---
                    
                    # Example: Process the object
                    $ProcessedItem = $Item.ToUpper()
                    
                    # Example: Create result object
                    $ResultObject = [PSCustomObject]@{
                        OriginalValue = $Item
                        ProcessedValue = $ProcessedItem
                        Parameter = $ParameterName
                        Timestamp = Get-Date
                        Success = $true
                    }
                    
                    # Add to results
                    $Results.Add($ResultObject)
                    $ProcessedCount++
                    
                    # Write to pipeline continuously (optional)
                    Write-Output $ResultObject
                }
                else {
                    Write-Verbose "Action cancelled for: $Item"
                }
            }
            catch {
                $ErrorCount++
                Write-Error "Error processing '$Item': $($_.Exception.Message)"
                
                # Choose whether to continue or abort
                if (-not $Force) {
                    throw
                }
                else {
                    Write-Warning "Continuing despite error (Force is enabled)"
                    continue
                }
            }
        }
    }
    
    end {
        try {
            Write-Verbose "=== END: Finalizing function ==="
            
            # --- YOUR FINALIZATION CODE HERE ---
            
            # Summarize results
            Write-Verbose "Total objects processed: $ProcessedCount"
            Write-Verbose "Total errors: $ErrorCount"
            
            # Return summary (optional)
            if ($ProcessedCount -gt 0) {
                Write-Verbose "Function completed successfully"
            }
            
            # If you haven't written results continuously in the process block,
            # you can return the entire results list here:
            # return $Results
        }
        catch {
            Write-Error "Error during finalization: $($_.Exception.Message)"
            throw
        }
        finally {
            # Cleanup if necessary
            Write-Verbose "Performing cleanup..."
        }
    }
}
