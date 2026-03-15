
$content = Get-Content "c:\Dev\Project2\health_system\lib\features\profile\screens\profile_screen.dart" -Raw

$replacement = @"
      if (confirmed != true || !mounted) return;

      // Clear cached data on logout to prevent cross-account bugs
      context.read<FeaturesProfileProvider>().clearProfile();
      context.read<TargetProfileProvider>().clearData();

      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
"@

$content = $content -replace "(?s)      if \(confirmed != true \|\| \!mounted\) return;\s+await context.read<AuthProvider>\(\).logout\(\);\s+if \(\!mounted\) return;\s+Navigator.pushNamedAndRemoveUntil\(", $replacement

Set-Content "c:\Dev\Project2\health_system\lib\features\profile\screens\profile_screen.dart" -Value $content

