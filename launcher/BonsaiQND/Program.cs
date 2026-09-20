using System.Diagnostics;
using System.Net.Http;
using System.Text;

namespace BonsaiQND;

internal sealed record ModeOption(string Key, string Label, string Profile, int DefaultContext, int MaxContext, int[] Contexts)
{
    public override string ToString() => Label;
}

internal sealed record LaunchPlan(string Profile, int Context, string Bind);

internal static class LaunchPlanner
{
    public static readonly ModeOption[] Modes =
    [
        new("nvidia", "NVIDIA RTX 3060 — Bonsai 2 27B / CUDA", "nvidia-rtx3060", 65536, 262144, [65536, 131072, 196608, 262144]),
        new("amd", "AMD RX 6950 XT — Bonsai 2 27B / Vulkan", "amd-rx6950xt", 65536, 262144, [65536, 131072, 196608, 262144]),
        new("cpu", "CPU (Windows) — Bonsai 27B / Q1_0", "windows-cpu", 8192, 8192, [8192])
    ];

    public static LaunchPlan Create(string mode, int context, bool lan)
    {
        var selected = Modes.FirstOrDefault(m => string.Equals(m.Key, mode, StringComparison.OrdinalIgnoreCase))
            ?? throw new ArgumentException($"Unknown mode '{mode}'.");
        if (context < 1024 || context > selected.MaxContext)
            throw new ArgumentOutOfRangeException(nameof(context), $"Context for {selected.Key} must be between 1024 and {selected.MaxContext}.");
        return new LaunchPlan(selected.Profile, context, lan ? "0.0.0.0" : "127.0.0.1");
    }
}

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Length >= 4 && args[0] == "--plan")
        {
            try
            {
                var plan = LaunchPlanner.Create(args[1], int.Parse(args[2]), string.Equals(args[3], "lan", StringComparison.OrdinalIgnoreCase));
                Console.WriteLine($"PROFILE={plan.Profile}");
                Console.WriteLine($"CONTEXT={plan.Context}");
                Console.WriteLine($"BIND={plan.Bind}");
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.Message);
                return 2;
            }
        }

        ApplicationConfiguration.Initialize();
        Application.Run(new MainForm());
        return 0;
    }
}

internal sealed class MainForm : Form
{
    private readonly ComboBox _mode = new() { DropDownStyle = ComboBoxStyle.DropDownList };
    private readonly ComboBox _context = new() { DropDownStyle = ComboBoxStyle.DropDownList };
    private readonly CheckBox _lan = new() { Text = "Udostępnij API w sieci lokalnej (0.0.0.0:8080)", AutoSize = true };
    private readonly Button _start = new() { Text = "Uruchom", Width = 130, Height = 34 };
    private readonly Button _stop = new() { Text = "Zatrzymaj", Width = 130, Height = 34, Enabled = false };
    private readonly Label _status = new() { Text = "Gotowy", AutoSize = true };
    private readonly TextBox _log = new() { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, WordWrap = false };
    private readonly string _root;
    private Process? _serverProcess;
    private bool _intentionalStop;

    public MainForm()
    {
        Text = "Bonsai QND";
        Width = 700;
        Height = 540;
        MinimumSize = new Size(620, 460);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.Sizable;
        _root = FindRoot();

        foreach (var mode in LaunchPlanner.Modes) _mode.Items.Add(mode);
        _mode.SelectedIndex = 0;
        _mode.SelectedIndexChanged += (_, _) => RefreshContexts();
        RefreshContexts();

        var title = new Label
        {
            Text = "Bonsai QND",
            Font = new Font(Font.FontFamily, 16, FontStyle.Bold),
            AutoSize = true
        };
        var subtitle = new Label
        {
            Text = "Wybierz sprzęt, kontekst i dostęp LAN. Program przygotuje runtime i uruchomi serwer w tle.",
            AutoSize = true
        };

        var grid = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            Height = 190,
            ColumnCount = 2,
            RowCount = 5,
            Padding = new Padding(12),
            AutoSize = false
        };
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 120));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        grid.Controls.Add(new Label { Text = "Tryb", AutoSize = true, Anchor = AnchorStyles.Left }, 0, 0);
        grid.Controls.Add(_mode, 1, 0);
        _mode.Dock = DockStyle.Fill;
        grid.Controls.Add(new Label { Text = "Kontekst", AutoSize = true, Anchor = AnchorStyles.Left }, 0, 1);
        grid.Controls.Add(_context, 1, 1);
        _context.Dock = DockStyle.Fill;
        grid.Controls.Add(new Label { Text = "Sieć", AutoSize = true, Anchor = AnchorStyles.Left }, 0, 2);
        grid.Controls.Add(_lan, 1, 2);

        var buttons = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.LeftToRight, AutoSize = true };
        buttons.Controls.Add(_start);
        buttons.Controls.Add(_stop);
        grid.Controls.Add(new Label { Text = "Sterowanie", AutoSize = true, Anchor = AnchorStyles.Left }, 0, 3);
        grid.Controls.Add(buttons, 1, 3);
        grid.Controls.Add(new Label { Text = "Status", AutoSize = true, Anchor = AnchorStyles.Left }, 0, 4);
        grid.Controls.Add(_status, 1, 4);

        var top = new FlowLayoutPanel { Dock = DockStyle.Top, Height = 68, Padding = new Padding(12, 8, 12, 0), FlowDirection = FlowDirection.TopDown };
        top.Controls.Add(title);
        top.Controls.Add(subtitle);

        _log.Dock = DockStyle.Fill;
        _log.Font = new Font(FontFamily.GenericMonospace, 9);
        _log.BackColor = SystemColors.Window;

        Controls.Add(_log);
        Controls.Add(grid);
        Controls.Add(top);

        _start.Click += StartClicked;
        _stop.Click += async (_, _) => await StopServerAsync();
        FormClosing += OnFormClosing;
        AppendLog($"QND root: {_root}");
    }

    private ModeOption SelectedMode => (ModeOption)_mode.SelectedItem!;

    private void RefreshContexts()
    {
        if (_mode.SelectedItem is not ModeOption selected) return;
        _context.Items.Clear();
        foreach (var value in selected.Contexts) _context.Items.Add(value);
        _context.SelectedItem = selected.DefaultContext;
        if (_context.SelectedIndex < 0) _context.SelectedIndex = 0;
    }

    private async void StartClicked(object? sender, EventArgs e)
    {
        if (_serverProcess is { HasExited: false }) return;
        try
        {
            var mode = SelectedMode;
            var context = Convert.ToInt32(_context.SelectedItem);
            var plan = LaunchPlanner.Create(mode.Key, context, _lan.Checked);
            SetBusy(true);
            _status.Text = "Sprawdzanie / przygotowanie runtime...";
            AppendLog($"=== {mode.Label} | context={plan.Context} | bind={plan.Bind} ===");
            AppendLog("Uruchamiam setup. Jeśli runtime jest już gotowy, QND zakończy ten etap od razu.");
            var setupExit = await RunPowerShellOnceAsync("setup", plan, serverOnly: false);
            if (setupExit != 0) throw new InvalidOperationException($"Setup zakończył się kodem {setupExit}.");

            _status.Text = "Uruchamianie serwera...";
            _serverProcess = StartPowerShell("start", plan, serverOnly: true);
            _intentionalStop = false;
            _serverProcess.EnableRaisingEvents = true;
            _serverProcess.Exited += (_, _) => BeginInvoke(() => ServerExited());
            await WaitForApiAsync(_serverProcess);
            _status.Text = plan.Bind == "0.0.0.0" ? "Działa — API dostępne w LAN na porcie 8080" : "Działa — API tylko lokalnie na porcie 8080";
            _stop.Enabled = true;
            _start.Enabled = false;
            _mode.Enabled = _context.Enabled = _lan.Enabled = false;
            AppendLog("[OK] Serwer gotowy: http://127.0.0.1:8080/v1");
            if (plan.Bind == "0.0.0.0") AppendLog("[LAN] Klienci używają rzeczywistego adresu IP tego komputera, np. http://192.168.1.50:8080/v1");
        }
        catch (Exception ex)
        {
            AppendLog($"[ERROR] {ex.Message}");
            _status.Text = "Błąd";
            await StopServerAsync();
        }
        finally
        {
            if (_serverProcess is null || _serverProcess.HasExited) SetBusy(false);
        }
    }

    private Process StartPowerShell(string command, LaunchPlan plan, bool serverOnly)
    {
        var script = Path.Combine(_root, "qnd.ps1");
        if (!File.Exists(script)) throw new FileNotFoundException("Nie znaleziono qnd.ps1.", script);
        var psi = new ProcessStartInfo
        {
            FileName = GetWindowsPowerShell(),
            WorkingDirectory = _root,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        psi.ArgumentList.Add("-NoProfile");
        psi.ArgumentList.Add("-ExecutionPolicy");
        psi.ArgumentList.Add("Bypass");
        psi.ArgumentList.Add("-File");
        psi.ArgumentList.Add(script);
        psi.ArgumentList.Add(command);
        psi.ArgumentList.Add("-Profile");
        psi.ArgumentList.Add(plan.Profile);
        psi.ArgumentList.Add("-Context");
        psi.ArgumentList.Add(plan.Context.ToString());
        if (command == "start")
        {
            psi.ArgumentList.Add("-Bind");
            psi.ArgumentList.Add(plan.Bind);
            if (serverOnly) psi.ArgumentList.Add("-ServerOnly");
        }
        psi.Environment["QND_ROOT"] = _root;

        var process = new Process { StartInfo = psi };
        process.OutputDataReceived += (_, e) => { if (!string.IsNullOrWhiteSpace(e.Data)) AppendLogThreadSafe(e.Data); };
        process.ErrorDataReceived += (_, e) => { if (!string.IsNullOrWhiteSpace(e.Data)) AppendLogThreadSafe(e.Data); };
        if (!process.Start()) throw new InvalidOperationException("Nie udało się uruchomić Windows PowerShell.");
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        return process;
    }

    private async Task<int> RunPowerShellOnceAsync(string command, LaunchPlan plan, bool serverOnly)
    {
        using var process = StartPowerShell(command, plan, serverOnly);
        await process.WaitForExitAsync();
        return process.ExitCode;
    }

    private async Task WaitForApiAsync(Process process)
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
        for (var i = 0; i < 180; i++)
        {
            if (process.HasExited) throw new InvalidOperationException($"Serwer zakończył działanie podczas startu (kod {process.ExitCode}).");
            try
            {
                using var response = await client.GetAsync("http://127.0.0.1:8080/v1/models");
                if (response.IsSuccessStatusCode) return;
            }
            catch (HttpRequestException) { }
            catch (TaskCanceledException) { }
            await Task.Delay(1000);
        }
        throw new TimeoutException("Serwer nie zgłosił gotowości w ciągu 180 sekund.");
    }

    private async Task StopServerAsync()
    {
        var process = _serverProcess;
        if (process is null) { SetBusy(false); return; }
        _intentionalStop = true;
        try
        {
            if (!process.HasExited)
            {
                AppendLog("Zatrzymuję serwer...");
                process.Kill(entireProcessTree: true);
                await process.WaitForExitAsync();
            }
        }
        catch (Exception ex) { AppendLog($"[WARN] {ex.Message}"); }
        finally
        {
            process.Dispose();
            _serverProcess = null;
            _status.Text = "Zatrzymany";
            _stop.Enabled = false;
            _start.Enabled = true;
            _mode.Enabled = _context.Enabled = _lan.Enabled = true;
        }
    }

    private void ServerExited()
    {
        if (_serverProcess is null) return;
        var code = _serverProcess.ExitCode;
        if (!_intentionalStop) AppendLog($"[WARN] Proces serwera zakończył się kodem {code}.");
        _status.Text = _intentionalStop ? "Zatrzymany" : "Serwer zakończył działanie";
        _serverProcess.Dispose();
        _serverProcess = null;
        _stop.Enabled = false;
        _start.Enabled = true;
        _mode.Enabled = _context.Enabled = _lan.Enabled = true;
    }

    private void OnFormClosing(object? sender, FormClosingEventArgs e)
    {
        if (_serverProcess is not { HasExited: false }) return;
        var answer = MessageBox.Show(this, "Serwer Bonsai QND nadal działa. Zatrzymać go i zamknąć program?", "Bonsai QND", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
        if (answer == DialogResult.No) { e.Cancel = true; return; }
        try { _intentionalStop = true; _serverProcess.Kill(entireProcessTree: true); } catch { }
    }

    private void SetBusy(bool busy)
    {
        _start.Enabled = !busy;
        if (_serverProcess is null || _serverProcess.HasExited)
        {
            _mode.Enabled = !busy;
            _context.Enabled = !busy;
            _lan.Enabled = !busy;
        }
    }

    private void AppendLogThreadSafe(string text)
    {
        if (IsDisposed) return;
        if (InvokeRequired) BeginInvoke(() => AppendLog(text)); else AppendLog(text);
    }

    private void AppendLog(string text)
    {
        if (_log.TextLength > 200_000) _log.Clear();
        _log.AppendText($"[{DateTime.Now:HH:mm:ss}] {text}{Environment.NewLine}");
        _log.SelectionStart = _log.TextLength;
        _log.ScrollToCaret();
    }

    private static string GetWindowsPowerShell()
    {
        var candidate = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe");
        return File.Exists(candidate) ? candidate : "powershell.exe";
    }

    private static string FindRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        for (var i = 0; i < 8 && dir is not null; i++, dir = dir.Parent)
        {
            if (File.Exists(Path.Combine(dir.FullName, "qnd.ps1"))) return dir.FullName;
        }
        return AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
    }
}
