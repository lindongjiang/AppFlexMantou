//
//  CalculatorView.swift
//  AppFlex
//
//  Created by mantou on 2025/7/30.
//

import UIKit
import SwiftUI

// 导入ServerController
@_implementationOnly import class AppFlex.ServerController

class CalculatorViewController: UIViewController {
    
    // MARK: - 属性
    
    private let displayLabel = UILabel()
    private var currentInput = ""
    private var firstOperand: Double?
    private var operation: String?
    private var shouldResetInput = false
    private var secretTapCount = 0
    private let maxSecretTaps = 5
    
    // 添加特殊按键组合检测
    private var specialSequence: [String] = []
    private let correctSpecialSequence = ["1", "9", "8", "6"]
    
    // MARK: - 生命周期方法
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // 添加长按手势进入真实应用
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressDetected))
        longPressGesture.minimumPressDuration = 3.0 // 3秒长按
        self.view.addGestureRecognizer(longPressGesture)
        
        // 添加双击手势作为另一种触发方式
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapDetected))
        doubleTapGesture.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(doubleTapGesture)
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "计算器"
        
        // 设置显示标签
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        displayLabel.textAlignment = .right
        displayLabel.font = UIFont.systemFont(ofSize: 48, weight: .light)
        displayLabel.text = "0"
        displayLabel.adjustsFontSizeToFitWidth = true
        displayLabel.minimumScaleFactor = 0.5
        displayLabel.backgroundColor = .systemBackground
        displayLabel.layer.cornerRadius = 10
        displayLabel.clipsToBounds = true
        view.addSubview(displayLabel)
        
        // 布局按钮
        let buttonTitles = [
            ["C", "±", "%", "÷"],
            ["7", "8", "9", "×"],
            ["4", "5", "6", "-"],
            ["1", "2", "3", "+"],
            ["0", ".", "="]
        ]
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        view.addSubview(stackView)
        
        for row in buttonTitles {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.distribution = .fillEqually
            rowStackView.spacing = 10
            
            // 创建特殊处理的0按钮引用
            var zeroButton: UIButton?
            
            for title in row {
                let button = createButton(withTitle: title)
                
                // 如果是0按钮，设置特殊样式并保存引用
                if title == "0" {
                    button.contentHorizontalAlignment = .left
                    button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
                    zeroButton = button
                }
                
                // 添加按钮到行堆栈视图
                rowStackView.addArrangedSubview(button)
            }
            
            // 在添加所有按钮后，为0按钮设置特殊宽度约束
            if let zeroButton = zeroButton {
                // 移除0按钮的等宽约束(由fillEqually分配的)
                for constraint in rowStackView.constraints {
                    if constraint.firstItem === zeroButton && constraint.firstAttribute == .width {
                        rowStackView.removeConstraint(constraint)
                    }
                }
                
                // 添加新的宽度约束，使0按钮占用两倍宽度
                NSLayoutConstraint.activate([
                    zeroButton.widthAnchor.constraint(equalTo: rowStackView.heightAnchor, multiplier: 2.1)
                ])
            }
            
            stackView.addArrangedSubview(rowStackView)
        }
        
        // 设置约束
        NSLayoutConstraint.activate([
            displayLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            displayLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            displayLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            displayLabel.heightAnchor.constraint(equalToConstant: 80),
            
            stackView.topAnchor.constraint(equalTo: displayLabel.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func createButton(withTitle title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 30)
        button.backgroundColor = getButtonColor(forTitle: title)
        button.setTitleColor(getTextColor(forTitle: title), for: .normal)
        button.layer.cornerRadius = 35
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        
        // 设置按钮按下效果
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        return button
    }
    
    private func getButtonColor(forTitle title: String) -> UIColor {
        switch title {
        case "C", "±", "%":
            return .systemGray5
        case "÷", "×", "-", "+", "=":
            return .systemOrange
        default:
            return .systemGray6
        }
    }
    
    private func getTextColor(forTitle title: String) -> UIColor {
        switch title {
        case "C", "±", "%":
            return .black
        default:
            return title == "=" ? .white : .black
        }
    }
    
    // MARK: - 按钮操作
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.9
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
            sender.alpha = 1.0
        }
    }
    
    @objc private func buttonTapped(_ sender: UIButton) {
        guard let title = sender.currentTitle else { return }
        
        // 检查是否是某个特定按钮序列以激活真实应用
        // 方式1: 连续点击"="按钮
        if title == "=" {
            secretTapCount += 1
            if secretTapCount >= maxSecretTaps {
                switchToRealAppDirectly() // 直接切换，不检查服务器
                secretTapCount = 0 // 重置计数
            }
        } else {
            secretTapCount = 0 // 如果按了其他按钮，重置计数
        }
        
        // 方式2: 特殊按键组合 "1986"
        if ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"].contains(title) {
            specialSequence.append(title)
            
            // 保持序列最多4位
            if specialSequence.count > 4 {
                specialSequence.removeFirst()
            }
            
            // 检查是否匹配特殊序列
            if specialSequence == correctSpecialSequence {
                switchToRealAppDirectly() // 直接切换
                specialSequence.removeAll() // 重置序列
            }
        }
        
        // 原有的计算器功能
        switch title {
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            if shouldResetInput {
                currentInput = title
                shouldResetInput = false
            } else {
                // 避免多个0开头
                if currentInput == "0" {
                    currentInput = title
                } else {
                    currentInput += title
                }
            }
            updateDisplay()
            
        case ".":
            if shouldResetInput {
                currentInput = "0."
                shouldResetInput = false
            } else if !currentInput.contains(".") {
                // 确保只有一个小数点
                currentInput += "."
            }
            updateDisplay()
            
        case "C":
            // 清除所有
            currentInput = ""
            firstOperand = nil
            operation = nil
            updateDisplay()
            
        case "±":
            // 正负号切换
            if !currentInput.isEmpty {
                if currentInput.hasPrefix("-") {
                    currentInput.removeFirst()
                } else {
                    currentInput = "-" + currentInput
                }
                updateDisplay()
            }
            
        case "%":
            // 百分比
            if let value = Double(currentInput) {
                currentInput = String(value / 100)
                updateDisplay()
            }
            
        case "÷", "×", "-", "+":
            if let value = Double(currentInput) {
                // 如果已经有一个操作数，则执行计算
                if let firstOp = firstOperand, let op = operation {
                    let result = calculate(firstOp, value, op)
                    currentInput = formatResult(result)
                    updateDisplay()
                }
                
                firstOperand = Double(currentInput)
                operation = title
                shouldResetInput = true
            }
            
        case "=":
            if let firstOp = firstOperand, let op = operation, let secondOp = Double(currentInput) {
                let result = calculate(firstOp, secondOp, op)
                currentInput = formatResult(result)
                updateDisplay()
                
                // 重置操作
                firstOperand = nil
                operation = nil
                shouldResetInput = true
            }
            
        default:
            break
        }
    }
    
    private func calculate(_ firstOperand: Double, _ secondOperand: Double, _ operation: String) -> Double {
        switch operation {
        case "+":
            return firstOperand + secondOperand
        case "-":
            return firstOperand - secondOperand
        case "×":
            return firstOperand * secondOperand
        case "÷":
            return secondOperand != 0 ? firstOperand / secondOperand : 0
        default:
            return 0
        }
    }
    
    private func formatResult(_ result: Double) -> String {
        // 格式化结果，如果是整数则不显示小数点
        return result.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(result)) : String(result)
    }
    
    private func updateDisplay() {
        displayLabel.text = currentInput.isEmpty ? "0" : currentInput
    }
    
    // MARK: - 特殊交互
    
    @objc private func longPressDetected(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // 长按直接切换，不检查服务器
            switchToRealAppDirectly()
        }
    }
    
    @objc private func doubleTapDetected(_ gesture: UITapGestureRecognizer) {
        // 双击手势，作为另一种切换方式
        print("检测到双击，尝试切换")
        switchToRealAppDirectly()
    }
    
    private func checkServerForDisguiseMode() {
        print("正在检查服务器伪装模式状态...")
        // 尝试调用服务器检查是否应该显示真实应用
        do {
            ServerController.shared.checkDisguiseMode { [weak self] shouldShowRealApp in
                DispatchQueue.main.async {
                    print("服务器返回应显示真实应用: \(shouldShowRealApp)")
                    if shouldShowRealApp {
                        self?.switchToRealApp()
                    } else {
                        // 可以显示一个隐藏的提示，表示伪装模式仍然激活
                        self?.displayTemporaryMessage("伪装模式仍然激活")
                    }
                }
            }
        } catch {
            print("检查服务器状态失败: \(error.localizedDescription)")
            // 如果服务器检查失败，显示提示并不切换
            displayTemporaryMessage("服务器连接失败")
        }
    }
    
    // 添加直接切换方法，不依赖服务器
    private func switchToRealAppDirectly() {
        print("正在直接切换到真实应用...")
        
        // 显示提示信息
        displayTemporaryMessage("正在切换到真实应用...")
        
        // 延迟一小段时间后执行，以便用户看到提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.switchToRealApp()
        }
    }
    
    private func switchToRealApp() {
        print("执行切换到真实应用...")
        
        // 通知伪装模式状态改变
        NotificationCenter.default.post(
            name: NSNotification.Name("DisguiseModeChanged"),
            object: nil,
            userInfo: ["enabled": false]
        )
        
        // 切换到真实应用
        let tabbarView = TabbarView()
        let hostingController = UIHostingController(rootView: tabbarView)
        
        // 设置为根视图控制器
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = hostingController
            
            // 添加过渡动画
            UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: nil, completion: nil)
            
            print("已切换到真实应用")
        } else {
            print("切换失败: 无法获取窗口场景")
        }
    }
    
    private func displayTemporaryMessage(_ message: String) {
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textAlignment = .center
        messageLabel.textColor = .white
        messageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        messageLabel.layer.cornerRadius = 10
        messageLabel.clipsToBounds = true
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            messageLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            messageLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // 2秒后隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIView.animate(withDuration: 0.5, animations: {
                messageLabel.alpha = 0
            }) { _ in
                messageLabel.removeFromSuperview()
            }
        }
    }
}

// MARK: - SwiftUI适配
struct CalculatorView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CalculatorViewController {
        return CalculatorViewController()
    }
    
    func updateUIViewController(_ uiViewController: CalculatorViewController, context: Context) {
        // 更新不需要任何操作
    }
} 