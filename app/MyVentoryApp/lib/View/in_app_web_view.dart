import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// A page that displays a web page within the app using WebView
class InAppWebViewPage extends StatefulWidget {
  final Uri uri;
  final String title;

  const InAppWebViewPage({
    super.key,
    required this.uri,
    required this.title,
  });

  @override
  State<InAppWebViewPage> createState() => _InAppWebViewPageState();
}

class _InAppWebViewPageState extends State<InAppWebViewPage> {
  late WebViewController controller;
  bool isLoading = true;
  double progress = 0.0;

  @override
  void initState() {
    super.initState();

    // Initialize WebView controller
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onProgress: (int progressValue) {
            setState(() {
              progress = progressValue / 100.0;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading page: ${error.description}'),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
      )
      ..loadRequest(widget.uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color.fromARGB(255, 0, 107, 96),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              controller.reload();
            },
          ),
          // Open in external browser button
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              try {
                if (await canLaunchUrl(widget.uri)) {
                  await launchUrl(
                    widget.uri,
                    mode: LaunchMode.externalApplication,
                  );
                }
              } catch (e) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Could not open external browser: $e")),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color.fromARGB(255, 0, 150, 136),
                  ),
                ),
                if (progress < 0.1)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 100.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
        ],
      ),
      // Add a bottom navigation bar with basic controls
      bottomNavigationBar: Container(
        height: 50.0,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5.0,
              spreadRadius: 2.0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await controller.canGoBack()) {
                  await controller.goBack();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () async {
                if (await controller.canGoForward()) {
                  await controller.goForward();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                controller.loadRequest(widget.uri);
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}