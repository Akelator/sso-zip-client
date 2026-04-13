using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Interactivity;
namespace ssa_zip_client;

public partial class MainWindow : Window
{
    private bool prod = true;
    private string folder { get { return this.prod ? AppContext.BaseDirectory : Path.Combine(AppContext.BaseDirectory, "TEST"); } }
    private const string packResourceName = "ssa-zip-client.scripts.ssa-zip-pack.bat";
    private const string unpackResourceName = "ssa-zip-client.scripts.ssa-zip-unpack.bat";
    private readonly string[] logLines = [
        "ok",                                                       //! 0
        "Unknown error",                                            //! 1
        "There are no files to synchronize",                        //! 2  
        "Incorrect password",                                       //! 3
        "Old ZIP content could not be deleted",                     //! 4
        "New content could not be added to ZIP",                    //! 5
        "ZIP file could not be created",                            //! 6
        "Empty protected ZIP could not be initialized",             //! 7
        "ZIP file not found",                                       //! 8
        "Destination folder is not empty",                          //! 9
        "ZIP content could not be extracted"                        //! 10
    ];
    private bool isBusy;

    public MainWindow()
    {
        InitializeComponent();
        if (!this.prod) Directory.CreateDirectory(this.folder);
        this.baseDirectoryTextBlock.Text = this.folder;
        this.packButton.Click += this.onPackButtonClick;
        this.unpackButton.Click += this.onUnpackButtonClick;
    }

    private async void onPackButtonClick(object? sender, RoutedEventArgs e)
    {
        await this.runActionAsync("pack", packResourceName);
    }

    private async void onUnpackButtonClick(object? sender, RoutedEventArgs e)
    {
        await this.runActionAsync("unpack", unpackResourceName);
    }

    private async Task runActionAsync(string operation, string resourceName)
    {
        if (this.isBusy) return;
        string password = this.passwordTextBox.Text ?? string.Empty;
        if (string.IsNullOrWhiteSpace(password))
        {
            this.statusTextBlock.Text = "Password is required.";
            return;
        }
        this.isBusy = true;
        this.packButton.IsEnabled = false;
        this.unpackButton.IsEnabled = false;
        this.statusTextBlock.Text = $"Running {operation}................";
        string batchPath = this.extractEmbeddedBatToTemp(resourceName, $"ssa-zip-{operation}.bat");
        int exitCode;
        try { exitCode = await this.runBatchAsync(batchPath, password); }
        catch { exitCode = 1; }
        finally
        {
            this.tryDeleteFile(batchPath);
            this.isBusy = false;
            this.packButton.IsEnabled = true;
            this.unpackButton.IsEnabled = true;
        }
        this.statusTextBlock.Text = exitCode == 0 ? $"{operation} finished." : $"{this.logLines[exitCode]}";
    }


    private string extractEmbeddedBatToTemp(string resourceName, string fileName)
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        string tempDirectory = this.folder;
        string outputPath = Path.Combine(tempDirectory, fileName);
        Directory.CreateDirectory(tempDirectory);
        using Stream resourceStream = assembly.GetManifestResourceStream(resourceName) ?? throw new InvalidOperationException($"Embedded resource '{resourceName}' not found.");
        using FileStream fileStream = new(outputPath, FileMode.Create, FileAccess.Write, FileShare.None);
        resourceStream.CopyTo(fileStream);
        return outputPath;
    }

    private async Task<int> runBatchAsync(string batchPath, string password)
    {
        string arguments = $"/c \"\"{batchPath}\" \"{password}\"\"";
        ProcessStartInfo startInfo = new()
        {
            FileName = "cmd.exe",
            Arguments = arguments,
            WorkingDirectory = this.folder,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        using Process process = new() { StartInfo = startInfo };

        process.Start();

        Task<string> outputTask = process.StandardOutput.ReadToEndAsync();
        Task<string> errorTask = process.StandardError.ReadToEndAsync();

        await process.WaitForExitAsync();

        string output = await outputTask;
        string error = await errorTask;

        return process.ExitCode;
    }

    private void tryDeleteFile(string path)
    {
        try { if (File.Exists(path)) File.Delete(path); }
        catch { }
    }
}