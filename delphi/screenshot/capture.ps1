# =====================================================================
#  capture.ps1
#  Launches each demo in a fresh conhost window, waits for the TUI to
#  render, captures the window's bitmap, then closes it.
#
#  Usage:  powershell -ExecutionPolicy Bypass -File capture.ps1
# =====================================================================
param(
    [int]$WaitMs = 1500   # how long to wait before capturing
)

Add-Type -AssemblyName System.Drawing,System.Windows.Forms

# --- Win32 helpers ---------------------------------------------------
$signature = @'
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr h, int n);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
}
'@
if (-not ('Win32' -as [type])) { Add-Type -TypeDefinition $signature }

# --- Capture a single window region ---------------------------------
function Capture-Window {
    param([IntPtr]$Hwnd, [string]$OutPath)
    $r = New-Object Win32+RECT
    [Win32]::GetWindowRect($Hwnd, [ref]$r) | Out-Null
    $w = $r.Right - $r.Left
    $h = $r.Bottom - $r.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size)
    $g.Dispose()
    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return $true
}

# --- Run + capture each demo ----------------------------------------
$root = Split-Path -Parent $PSCommandPath
$bin  = Join-Path (Split-Path -Parent $root) 'bin'
$out  = $root

$demos = @(
    # Keys: SendKeys notation. % = Alt, ~ = Enter, ^ = Ctrl
    @{ Exe='TVisionDemo.exe';   Keys='%h{DOWN}~';     Title='Greeting dialog' },
    @{ Exe='MMenuDemo.exe';     Keys='%m';            Title='Menu One open' },
    @{ Exe='TvAppDemo.exe';     Keys='%h~';           Title='About dialog' },
    @{ Exe='TvEditDemo.exe';    Keys='%f';            Title='File menu open' },
    @{ Exe='TvPaletteDemo.exe'; Keys='%t{DOWN}~';     Title='Palette view' },
    @{ Exe='TvDirDemo.exe';     Keys='%h~';           Title='About dialog' },
    @{ Exe='TvFormsDemo.exe';   Keys='';              Title='Phone book browser' }
    # AvsColor is a CLI tool with no TUI - excluded
)

foreach ($d in $demos) {
    $exe = Join-Path $bin $d.Exe
    if (-not (Test-Path $exe)) {
        Write-Warning "Missing $exe — skipped."
        continue
    }
    Write-Host "Capturing $($d.Exe) ..."

    # Spawn in its own console window
    $proc = Start-Process -FilePath $exe -PassThru -WindowStyle Normal
    Start-Sleep -Milliseconds 400

    # On modern Windows the console may be hosted in either conhost.exe
    # (MainWindowHandle on the demo process) or WindowsTerminal.exe
    # (MainWindowHandle 0 on the demo, but a WindowsTerminal process owns
    # a window whose title equals the launched command line).
    $hwnd = [IntPtr]::Zero
    $attempts = 30
    while ($attempts -gt 0 -and $hwnd -eq [IntPtr]::Zero) {
        Start-Sleep -Milliseconds 150
        $proc.Refresh()
        if ($proc.MainWindowHandle -ne 0) {
            $hwnd = $proc.MainWindowHandle
            break
        }
        # Look for a WindowsTerminal whose MainWindowTitle matches our exe path
        $term = Get-Process -Name 'WindowsTerminal' -ErrorAction SilentlyContinue |
                Where-Object { $_.MainWindowTitle -like "*$($d.Exe)" } |
                Select-Object -First 1
        if ($term) { $hwnd = $term.MainWindowHandle; break }
        $attempts--
    }
    if ($hwnd -eq [IntPtr]::Zero) {
        Write-Warning "  no window for $($d.Exe)"
        $proc | Stop-Process -Force -ErrorAction SilentlyContinue
        continue
    }

    [Win32]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 400

    # Send the per-demo key sequence to bring up an interesting view
    if ($d.Keys) {
        try { [System.Windows.Forms.SendKeys]::SendWait($d.Keys) } catch { }
        Start-Sleep -Milliseconds 600
    }
    Start-Sleep -Milliseconds $WaitMs

    $png = Join-Path $out ([IO.Path]::ChangeExtension($d.Exe, '.png'))
    if (Capture-Window -Hwnd $hwnd -OutPath $png) {
        Write-Host "  -> $png"
    } else {
        Write-Warning "  capture failed for $($d.Exe)"
    }

    $proc | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 200
}

Write-Host "`nAll captures written to: $out"
