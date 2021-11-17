import Foundation
import SwiftUI

/// `UITextfield` wrapper reads and writes to provided binding value.
/// Needed because iOS 15 won't allow us to intercept correctly the binding value in the original `SwiftUI` component.
/// Feel free to add modifiers as it is needed.
///
struct BindableTextfield: UIViewRepresentable {

    /// Placeholder of the textfield.
    ///
    let placeHolder: String?

    /// Binding to read content from and write content to.
    ///
    @Binding var text: String

    init(_ placeholder: String?, text: Binding<String>) {
        self.placeHolder = placeholder
        self._text = text
    }

    /// Creates view with the initial configuration.
    ///
    func makeUIView(context: Context) -> UITextField {
        let textfield = UITextField()
        textfield.placeholder = placeHolder
        textfield.delegate = context.coordinator
        return textfield
    }

    /// Creates coordinator.
    ///
    func makeCoordinator() -> Coordinator {
        Coordinator(_text)
    }

    /// Updates underlying view.
    ///
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
}

// MARK: Coordinator

extension BindableTextfield {
    /// Coordinator needed to listen to the `TextField` delegate and relay the input content to the binding value.
    ///
    final class Coordinator: NSObject, UITextFieldDelegate {

        /// Binding to set content from the `TextField` delegate.
        ///
        @Binding var text: String

        init(_ text: Binding<String>) {
            self._text = text
        }

        /// Relays the input value to the binding variable.
        ///
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if let currentInput = textField.text, let inputRange = Range(range, in: currentInput) {
                text = currentInput.replacingCharacters(in: inputRange, with: string)
            } else {
                text = string
            }
            return false
        }
    }
}
