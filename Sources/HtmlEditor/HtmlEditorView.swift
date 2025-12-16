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

    var isEditing = false

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

      let fixKeyboardScroll = """
      document.addEventListener('focusin', function() {
          setTimeout(() => {
              document.body.scrollTop = 0;
              document.documentElement.scrollTop = 0;
              window.scrollTo(0, 0);
          }, 50);
      });

      document.addEventListener('focusout', function() {
          setTimeout(() => {
              document.body.scrollTop = 0;
              document.documentElement.scrollTop = 0;
              window.scrollTo(0, 0);
          }, 50);
      });
      """
      webView.evaluateJavaScript(fixKeyboardScroll, completionHandler: nil)
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      if message.name == "contentChanged", let content = message.body as? String {
        DispatchQueue.main.async {
          self.parent.htmlContent = content
        }
      } else if message.name == "focusStateChanged", let focused = message.body as? Bool {
        self.isEditing = focused
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
    contentController.add(context.coordinator, name: "focusStateChanged")
    config.userContentController = contentController

    let webView = WKWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = context.coordinator
    webView.scrollView.isScrollEnabled = true
    if let htmlPath = Bundle.module.path(forResource: "html-editor", ofType: "html") {
      let url = URL(fileURLWithPath: htmlPath)
      webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    return webView
  }

  public func updateUIView(_ webView: WKWebView, context: Context) {
    if let coordinatorWebView = context.coordinator.webView, coordinatorWebView == webView {
      if !context.coordinator.isEditing {
        setText(htmlContent, in: webView)
      }
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
                        if (currentContent !== '\(escapedHtml)') {
                            var isFocused = editor.summernote('hasFocus');
                            if (!isFocused) {
                               editor.summernote('code', '\(escapedHtml)');
                            }
                        }
                    }
                }
            })();
            """
    webView.evaluateJavaScript(script, completionHandler: nil)
  }
}

