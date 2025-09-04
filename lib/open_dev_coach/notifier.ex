defmodule OpenDevCoach.Notifier do
  @moduledoc """
  Provides desktop notifications for OpenDevCoach.

  Supports multiple platforms:
  - Linux: notify-send
  - macOS: terminal-notifier
  - Windows: PowerShell toast notifications
  - Fallback: Console output
  """

  require Logger

  @doc """
  Sends a desktop notification with the given title and message.

  Returns {:ok, "notification sent"} on success or {:error, reason} on failure.
  """
  def notify(title, message) do
    case detect_platform() do
      :linux -> notify_linux(title, message)
      :macos -> notify_macos(title, message)
      :windows -> notify_windows(title, message)
      :unknown -> notify_fallback(title, message)
    end
  end

  # Private Functions

  defp detect_platform do
    case :os.type() do
      {:unix, :darwin} -> :macos
      {:unix, :linux} -> :linux
      {:win32, _} -> :windows
      _ -> :unknown
    end
  end

  defp notify_linux(title, message) do
    case System.cmd("notify-send", [title, message]) do
      {_output, 0} ->
        Logger.debug("Linux notification sent: #{title}")
        {:ok, "notification sent"}

      {error, _exit_code} ->
        Logger.warning("Linux notification failed: #{error}")
        notify_fallback(title, message)
    end
  end

  defp notify_macos(title, message) do
    case System.cmd("terminal-notifier", [
           "-title",
           title,
           "-message",
           message,
           "-sound",
           "default"
         ]) do
      {_output, 0} ->
        Logger.debug("macOS notification sent: #{title}")
        {:ok, "notification sent"}

      {error, _exit_code} ->
        Logger.warning("macOS notification failed: #{error}")
        notify_fallback(title, message)
    end
  end

  defp notify_windows(title, message) do
    # PowerShell command to show toast notification
    ps_command = """
    Add-Type -AssemblyName System.Windows.Forms
    $notification = New-Object System.Windows.Forms.NotifyIcon
    $notification.Icon = [System.Drawing.SystemIcons]::Information
    $notification.BalloonTipTitle = "#{title}"
    $notification.BalloonTipText = "#{message}"
    $notification.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
    $notification.Visible = $true
    $notification.ShowBalloonTip(5000)
    $notification.Dispose()
    """

    case System.cmd("powershell", ["-Command", ps_command]) do
      {_output, 0} ->
        Logger.debug("Windows notification sent: #{title}")
        {:ok, "notification sent"}

      {error, _exit_code} ->
        Logger.warning("Windows notification failed: #{error}")
        notify_fallback(title, message)
    end
  end

  defp notify_fallback(title, message) do
    # Fallback to console output when notification tools aren't available
    Logger.info("NOTIFICATION: #{title} - #{message}")
    {:ok, "notification logged to console"}
  end
end
