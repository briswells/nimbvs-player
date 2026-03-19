import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String?

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
            }
            Text(message)
                .font(.subheadline)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(NimbusTheme.Colors.surfaceElevated)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// Toast modifier for any view
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if isPresented {
                ToastView(message: message, icon: icon)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { isPresented = false }
                        }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, icon: String? = nil) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, icon: icon))
    }
}
