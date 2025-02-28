//
//  Untitled.swift
//  HitPay
//
//  Copyright © 2025 HitPay. All rights reserved.
//

import SwiftUI
import UIKit
import WebKit

public struct HtmlEditorView: UIViewRepresentable {
  @Binding var htmlContent: String

  public init(htmlContent: Binding<String>) {
    self._htmlContent = htmlContent
  }

  public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var parent: HtmlEditorView
    var webView: WKWebView?

    init(_ parent: HtmlEditorView) {
      self.parent = parent
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      print("WebView loaded successfully")
      self.webView = webView
      parent.setText(parent.htmlContent, in: webView)
      let observeChange = """
                      $('#summernote').on('summernote.change', function() {
                          window.webkit.messageHandlers.contentChanged.postMessage($('#summernote').summernote('code'));
                      });
                      """
      webView.evaluateJavaScript(observeChange, completionHandler: nil)
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      if message.name == "contentChanged", let content = message.body as? String {
        DispatchQueue.main.async {
          self.parent.htmlContent = content
        }
      }
    }
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  public func makeUIView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.defaultWebpagePreferences.allowsContentJavaScript = true

    let contentController = WKUserContentController()
    contentController.add(context.coordinator, name: "contentChanged")
    config.userContentController = contentController

    let webView = WKWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = context.coordinator

    if let htmlPath = Bundle.main.path(forResource: "html-editor", ofType: "html") {
      let url = URL(fileURLWithPath: htmlPath)
      webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    return webView
  }

  public func updateUIView(_ webView: WKWebView, context: Context) {
    if let coordinatorWebView = context.coordinator.webView, coordinatorWebView == webView {
      setText(htmlContent, in: webView)
    }
  }

  func setText(_ html: String, in webView: WKWebView) {
    let escapedHtml = html.replacingOccurrences(of: "'", with: "\\'")
    let script = """
        (function() {
            if (window.jQuery && $.fn.summernote) {
                var editor = $('#summernote');
                if (editor.length > 0) {
                    var currentContent = editor.summernote('code');
                    if (currentContent !== '\(escapedHtml)') { // Chỉ cập nhật nếu nội dung thay đổi
                        var isFocused = document.activeElement === editor[0]; // Kiểm tra editor có focus không
                        var selection = isFocused ? editor.summernote('createRange') : null; // Chỉ lưu range nếu đang focus

                        editor.summernote('code', '\(escapedHtml)'); // Cập nhật nội dung

                        if (isFocused && selection) {
                            editor.summernote('setRange', selection); // Chỉ khôi phục con trỏ nếu đã focus trước đó
                        }
                    }
                }
            }
        })();
        """
    webView.evaluateJavaScript(script, completionHandler: nil)
  }
}

