// 2>nul||@goto :batch
/*
:batch
@echo off
setlocal

:: find csc.exe
set "csc="
for /r "%SystemRoot%\Microsoft.NET\Framework\" %%# in ("*csc.exe") do  set "csc=%%#"

if not exist "%csc%" (
   echo no .net framework installed
   exit /b 10
)

if not exist "%~n0.exe" (
   call %csc% /nologo /r:"Microsoft.VisualBasic.dll" /out:"%~n0.exe" "%~dpsfnx0" || (
      exit /b %errorlevel% 
   )
)
%~n0.exe %*
endlocal & exit /b %errorlevel%

*/

// reference  
// https://gallery.technet.microsoft.com/scriptcenter/eeff544a-f690-4f6b-a586-11eea6fc5eb8

using System;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;
using Microsoft.VisualBasic;
using System.Windows.Forms;


/// Provides functions to capture the entire screen, or a particular window, and save it to a file. 

public class ScreenCapture
{

    /// Creates an Image object containing a screen shot of the entire desktop 

    public Image CaptureScreen(int x, int y, int width, int height)
    {
        return CaptureWindow(User32.GetDesktopWindow(), x, y, width, height);
    }

    /// Creates an Image object containing a screen shot of a specific window 

    private Image CaptureWindow(IntPtr handle, int x, int y, int width, int height)
    {
        // get te hDC of the target window 
        IntPtr hdcSrc = User32.GetWindowDC(handle);
        // create a device context we can copy to 
        IntPtr hdcDest = GDI32.CreateCompatibleDC(hdcSrc);
        // create a bitmap we can copy it to, 
        // using GetDeviceCaps to get the width/height 
        IntPtr hBitmap = GDI32.CreateCompatibleBitmap(hdcSrc, width, height);
        // select the bitmap object 
        IntPtr hOld = GDI32.SelectObject(hdcDest, hBitmap);
        // bitblt over 
        GDI32.BitBlt(hdcDest, 0, 0, width, height, hdcSrc, x, y, GDI32.SRCCOPY);
        // restore selection 
        GDI32.SelectObject(hdcDest, hOld);
        // clean up 
        GDI32.DeleteDC(hdcDest);
        User32.ReleaseDC(handle, hdcSrc);
        // get a .NET image object for it 
        Image img = Image.FromHbitmap(hBitmap);
        // free up the Bitmap object 
        GDI32.DeleteObject(hBitmap);
        return img;
    }

    public void CaptureScreenToFile(string filename, ImageFormat format)
    {
        const int ENUM_CURRENT_SETTINGS = -1;
        
        int x = 9999;
        int y = 0;

        int width = 0;
        int height = 0;

        foreach (Screen screen in Screen.AllScreens)
        {
            var dm = new DEVMODE();
            dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
            EnumDisplaySettings(screen.DeviceName, ENUM_CURRENT_SETTINGS, ref dm);

            if (dm.dmPositionX < x)
            {
                x = dm.dmPositionX;
            }
            if (dm.dmPositionY < y)
            {
                y = dm.dmPositionY;
            }
            
            width += dm.dmPelsWidth;

            if(dm.dmPelsHeight > height)
            {
                height = dm.dmPelsHeight;
            }

        }
        Image img = CaptureScreen(x, y, width, height);
        img.Save(filename, format);
    }

    static bool fullscreen = true;
    static String file = "screenshot.bmp";
    static System.Drawing.Imaging.ImageFormat format = System.Drawing.Imaging.ImageFormat.Bmp;

    static void parseArguments()
    {
        String[] arguments = Environment.GetCommandLineArgs();
        if (arguments.Length == 1)
        {
            printHelp();
            Environment.Exit(0);
        }
        if (arguments[1].ToLower().Equals("/h") || arguments[1].ToLower().Equals("/help"))
        {
            printHelp();
            Environment.Exit(0);
        }

        file = arguments[1];
        Dictionary<String, System.Drawing.Imaging.ImageFormat> formats =
        new Dictionary<String, System.Drawing.Imaging.ImageFormat>();

        formats.Add("bmp", System.Drawing.Imaging.ImageFormat.Bmp);
        formats.Add("emf", System.Drawing.Imaging.ImageFormat.Emf);
        formats.Add("exif", System.Drawing.Imaging.ImageFormat.Exif);
        formats.Add("jpg", System.Drawing.Imaging.ImageFormat.Jpeg);
        formats.Add("jpeg", System.Drawing.Imaging.ImageFormat.Jpeg);
        formats.Add("gif", System.Drawing.Imaging.ImageFormat.Gif);
        formats.Add("png", System.Drawing.Imaging.ImageFormat.Png);
        formats.Add("tiff", System.Drawing.Imaging.ImageFormat.Tiff);
        formats.Add("wmf", System.Drawing.Imaging.ImageFormat.Wmf);


        String ext = "";
        if (file.LastIndexOf('.') > -1)
        {
            ext = file.ToLower().Substring(file.LastIndexOf('.') + 1, file.Length - file.LastIndexOf('.') - 1);
        }
        else
        {
            Console.WriteLine("Invalid file name - no extension");
            Environment.Exit(7);
        }

        try
        {
            format = formats[ext];
        }
        catch (Exception e)
        {
            Console.WriteLine("Probably wrong file format:" + ext);
            Console.WriteLine(e.ToString());
            Environment.Exit(8);
        }

    }

    static void printHelp()
    {
        //clears the extension from the script name
        String scriptName = Environment.GetCommandLineArgs()[0];
        scriptName = scriptName.Substring(0, scriptName.Length);
        Console.WriteLine(scriptName + " captures the screen and saves it to a file.");
        Console.WriteLine("");
        Console.WriteLine("Usage:");
        Console.WriteLine(" " + scriptName + " filename");
        Console.WriteLine("");
        Console.WriteLine("filename - the file where the screen capture will be saved");
        Console.WriteLine("     allowed file extensions are - Bmp,Emf,Exif,Gif,Icon,Jpeg,Png,Tiff,Wmf.");
    }

    public static void Main()
    {
        User32.SetProcessDPIAware();
        
        parseArguments();
        ScreenCapture sc = new ScreenCapture();
        try
        {
            if (fullscreen)
            {
                Console.WriteLine("Taking a capture of the whole screen to " + file);
                sc.CaptureScreenToFile(file, format);
            }
        }
        catch (Exception e)
        {
            Console.WriteLine("Check if file path is valid " + file);
            Console.WriteLine(e.ToString());
        }
    }

    /// Helper class containing Gdi32 API functions 

    private class GDI32
    {

        public const int SRCCOPY = 0x00CC0020; // BitBlt dwRop parameter 
        [DllImport("gdi32.dll")]
        public static extern bool BitBlt(IntPtr hObject, int nXDest, int nYDest,
          int nWidth, int nHeight, IntPtr hObjectSource,
          int nXSrc, int nYSrc, int dwRop);
        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateCompatibleBitmap(IntPtr hDC, int nWidth,
          int nHeight);
        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateCompatibleDC(IntPtr hDC);
        [DllImport("gdi32.dll")]
        public static extern bool DeleteDC(IntPtr hDC);
        [DllImport("gdi32.dll")]
        public static extern bool DeleteObject(IntPtr hObject);
        [DllImport("gdi32.dll")]
        public static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);
    }


    /// Helper class containing User32 API functions 

    private class User32
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int left;
            public int top;
            public int right;
            public int bottom;
        }
        [DllImport("user32.dll")]
        public static extern IntPtr GetDesktopWindow();
        [DllImport("user32.dll")]
        public static extern IntPtr GetWindowDC(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern IntPtr ReleaseDC(IntPtr hWnd, IntPtr hDC);
        [DllImport("user32.dll")]
        public static extern IntPtr GetWindowRect(IntPtr hWnd, ref RECT rect);
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")]
        public static extern int SetProcessDPIAware();
    }

    [DllImport("user32.dll")]
   static extern bool EnumDisplaySettings(string lpszDeviceName, int iModeNum, ref DEVMODE lpDevMode);

   [StructLayout(LayoutKind.Sequential)]
   public struct DEVMODE
   {
      [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 0x20)]
      public string dmDeviceName;
      public short dmSpecVersion;
      public short dmDriverVersion;
      public short dmSize;
      public short dmDriverExtra;
      public int dmFields;
      public int dmPositionX;
      public int dmPositionY;
      public ScreenOrientation dmDisplayOrientation;
      public int dmDisplayFixedOutput;
      public short dmColor;
      public short dmDuplex;
      public short dmYResolution;
      public short dmTTOption;
      public short dmCollate;
      [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 0x20)]
      public string dmFormName;
      public short dmLogPixels;
      public int dmBitsPerPel;
      public int dmPelsWidth;
      public int dmPelsHeight;
      public int dmDisplayFlags;
      public int dmDisplayFrequency;
      public int dmICMMethod;
      public int dmICMIntent;
      public int dmMediaType;
      public int dmDitherType;
      public int dmReserved1;
      public int dmReserved2;
      public int dmPanningWidth;
      public int dmPanningHeight;
   }

}
