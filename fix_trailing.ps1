
$content = Get-Content -Raw "C:\Dev\Project2\health_system\lib\features\family\screens\search_user_screen.dart"

$replacement = @"
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          String initials = '?';
                          if (user.fullName != null && user.fullName!.isNotEmpty) {
                            initials = user.fullName![0].toUpperCase();
                          } else if (user.email.isNotEmpty) {
                            initials = user.email[0].toUpperCase();
                          }
                          
                          final isSelf = user.id == myId;
                          final isLinked = targetProvider.relationships.any((r) => r.patientId == user.id || r.caregiverId == user.id);
                          final isSentLocal = _sentRequestUserIds.contains(user.id);

                          return ListTile(
                            leading: CircleAvatar(child: Text(initials)),
                            title: Text(user.fullName ?? user.email),
                            subtitle: Text([if (user.phone != null) user.phone, user.email].join(' • ')),
                            trailing: isSelf 
                              ? const Text('Bạn', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                              : isLinked 
                                  ? const Text('Đã liên kết', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                                  : ElevatedButton(
                                      onPressed: isSentLocal ? null : () => _sendRequest(user),
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      child: Text(isSentLocal ? 'Đã gửi' : 'Gửi liên kết'),
                                    ),
                          );
                        },
"@

$content = $content -replace "(?s)                        itemBuilder: \(context, index\) \{.*?          return ListTile.*?          \);`n                        \},", $replacement

Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\search_user_screen.dart" -Value $content

