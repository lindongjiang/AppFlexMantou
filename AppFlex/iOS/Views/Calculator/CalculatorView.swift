//
//  CalculatorView.swift
//  AppFlex
//
//  Created by mantou on 2025/7/30.
//

import UIKit
import SwiftUI

class CalculatorViewController: UIViewController {
    
    // MARK: - 属性
    
    private let displayLabel = UILabel()
    private var historyDisplayLabel = UILabel() // 显示历史记录或上一步操作
    private var currentInput = ""
    private var firstOperand: Double?
    private var operation: String?
    private var shouldResetInput = false
    
    // 特殊序列变量保留但不显示任何提示
    private var specialSequence: [String] = []
    private let correctSpecialSequence = ["1", "9", "8", "6"]
    
    // 历史记录部分保留
    private var calculationHistory: [String] = []
    private let maxHistoryItems = 10
    
    // 主题设置保留
    private enum CalculatorTheme {
        case light
        case dark
        case colorful
    }
    private var currentTheme: CalculatorTheme = .light

    // 计算器模式
    private enum CalculatorMode {
        case basic
        case scientific
    }
    private var currentMode: CalculatorMode = .basic

    // 设置按钮
    private var settingsButton: UIButton!
    private var historyButton: UIButton!
    private var modeToggleButton: UIButton!
    private var themeButton: UIButton!

    // 科学计算按钮容器
    private var scientificButtonsContainer: UIStackView!
    private var basicButtonsContainer: UIStackView!
    
    // 控制按钮容器 - 声明为属性以便在整个类中访问
    private var controlButtonsContainer: UIStackView!
    
    // 保存布局约束的引用，以便能够激活/停用它们
    private var basicToControlConstraint: NSLayoutConstraint!
    private var basicToScientificConstraint: NSLayoutConstraint!

    // MARK: - 生命周期方法
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // 修改：使用服务器验证的触发方式
        
        // 添加长按手势 - 改为通过服务器验证
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressDetected))
        longPressGesture.minimumPressDuration = 3.0 // 3秒长按
        self.view.addGestureRecognizer(longPressGesture)
        
        // 添加双击手势 - 改为通过服务器验证
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapDetected))
        doubleTapGesture.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(doubleTapGesture)
        
        // 加载用户偏好设置
        loadUserPreferences()
    }
    
    // 新增：加载用户偏好设置
    private func loadUserPreferences() {
        if let savedTheme = UserDefaults.standard.string(forKey: "calculator_theme") {
            if savedTheme == "dark" {
                currentTheme = .dark
            } else if savedTheme == "colorful" {
                currentTheme = .colorful
            } else {
                currentTheme = .light
            }
        }
        
        if UserDefaults.standard.bool(forKey: "scientific_mode_enabled") {
            currentMode = .scientific
            toggleCalculatorMode()
        }
        
        applyTheme()
    }
    
    // 新增：应用主题
    private func applyTheme() {
        switch currentTheme {
        case .light:
            view.backgroundColor = .systemBackground
            displayLabel.backgroundColor = .systemBackground
            displayLabel.textColor = .black
            historyDisplayLabel.textColor = .darkGray
        case .dark:
            view.backgroundColor = .black
            displayLabel.backgroundColor = .black
            displayLabel.textColor = .white
            historyDisplayLabel.textColor = .lightGray
        case .colorful:
            view.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0)
            displayLabel.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0)
            displayLabel.textColor = .white
            historyDisplayLabel.textColor = UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0)
        }
        
        // 刷新所有按钮样式
        basicButtonsContainer.arrangedSubviews.forEach { rowStack in
            if let stackView = rowStack as? UIStackView {
                stackView.arrangedSubviews.forEach { button in
                    if let button = button as? UIButton, let title = button.currentTitle {
                        button.backgroundColor = getButtonColor(forTitle: title)
                        button.setTitleColor(getTextColor(forTitle: title), for: .normal)
                    }
                }
            }
        }
        
        if scientificButtonsContainer != nil {
            scientificButtonsContainer.arrangedSubviews.forEach { rowStack in
                if let stackView = rowStack as? UIStackView {
                    stackView.arrangedSubviews.forEach { button in
                        if let button = button as? UIButton, let title = button.currentTitle {
                            button.backgroundColor = getButtonColor(forTitle: title)
                            button.setTitleColor(getTextColor(forTitle: title), for: .normal)
                        }
                    }
                }
            }
        }
        
        // 更新控制按钮样式
        settingsButton.backgroundColor = getButtonColor(forTitle: "设置")
        historyButton.backgroundColor = getButtonColor(forTitle: "历史")
        modeToggleButton.backgroundColor = getButtonColor(forTitle: "模式")
        themeButton.backgroundColor = getButtonColor(forTitle: "主题")
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "科学计算器"
        
        // 设置历史显示标签
        historyDisplayLabel = UILabel()
        historyDisplayLabel.translatesAutoresizingMaskIntoConstraints = false
        historyDisplayLabel.textAlignment = .right
        historyDisplayLabel.font = UIFont.systemFont(ofSize: 18, weight: .light)
        historyDisplayLabel.text = ""
        historyDisplayLabel.textColor = .darkGray
        view.addSubview(historyDisplayLabel)
        
        // 设置主显示标签，优化显示长数字的能力
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        displayLabel.textAlignment = .right
        displayLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .light) // 使用等宽字体
        displayLabel.text = "0"
        displayLabel.adjustsFontSizeToFitWidth = true
        displayLabel.minimumScaleFactor = 0.3 // 允许更小的缩放比例以适应长数字
        displayLabel.backgroundColor = .systemBackground
        displayLabel.layer.cornerRadius = 10
        displayLabel.clipsToBounds = true
        view.addSubview(displayLabel)
        
        // 创建控制按钮容器
        controlButtonsContainer = UIStackView()
        controlButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        controlButtonsContainer.axis = .horizontal
        controlButtonsContainer.distribution = .fillEqually
        controlButtonsContainer.spacing = 10
        view.addSubview(controlButtonsContainer)
        
        // 创建设置按钮
        settingsButton = createControlButton(withTitle: "设置", action: #selector(settingsButtonTapped))
        historyButton = createControlButton(withTitle: "历史", action: #selector(historyButtonTapped))
        modeToggleButton = createControlButton(withTitle: "模式", action: #selector(modeToggleButtonTapped))
        themeButton = createControlButton(withTitle: "主题", action: #selector(themeButtonTapped))
        
        controlButtonsContainer.addArrangedSubview(settingsButton)
        controlButtonsContainer.addArrangedSubview(historyButton)
        controlButtonsContainer.addArrangedSubview(modeToggleButton)
        controlButtonsContainer.addArrangedSubview(themeButton)
        
        // 创建基础计算器按钮
        setupBasicCalculatorButtons()
        
        // 创建科学计算器按钮（初始隐藏）
        setupScientificCalculatorButtons()
        
        // 创建约束但先不激活
        basicToControlConstraint = basicButtonsContainer.topAnchor.constraint(equalTo: controlButtonsContainer.bottomAnchor, constant: 10)
        basicToScientificConstraint = basicButtonsContainer.topAnchor.constraint(equalTo: scientificButtonsContainer.bottomAnchor, constant: 10)
        
        // 基础模式下激活相应约束
        basicToControlConstraint.isActive = true
        
        // 设置约束
        NSLayoutConstraint.activate([
            historyDisplayLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            historyDisplayLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            historyDisplayLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            historyDisplayLabel.heightAnchor.constraint(equalToConstant: 25),
            
            displayLabel.topAnchor.constraint(equalTo: historyDisplayLabel.bottomAnchor, constant: 5),
            displayLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            displayLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            displayLabel.heightAnchor.constraint(equalToConstant: 80),
            
            controlButtonsContainer.topAnchor.constraint(equalTo: displayLabel.bottomAnchor, constant: 10),
            controlButtonsContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            controlButtonsContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            controlButtonsContainer.heightAnchor.constraint(equalToConstant: 40),
            
            basicButtonsContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            basicButtonsContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            basicButtonsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func createControlButton(withTitle title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .systemGray5
        button.setTitleColor(.black, for: .normal)
        button.layer.cornerRadius = 15
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // 设置按钮按下效果
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        return button
    }
    
    // 新增：创建基础计算器按钮
    private func setupBasicCalculatorButtons() {
        let buttonTitles = [
            ["C", "±", "%", "÷"],
            ["7", "8", "9", "×"],
            ["4", "5", "6", "-"],
            ["1", "2", "3", "+"],
            ["0", ".", "="]
        ]
        
        basicButtonsContainer = UIStackView()
        basicButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        basicButtonsContainer.axis = .vertical
        basicButtonsContainer.distribution = .fillEqually
        basicButtonsContainer.spacing = 10
        view.addSubview(basicButtonsContainer)
        
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
                    // 使用iOS 15兼容的方式设置按钮内容对齐
                    button.contentHorizontalAlignment = .left
                    if #available(iOS 15.0, *) {
                        var config = UIButton.Configuration.plain()
                        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0)
                        button.configuration = config
                    } else {
                        // 旧版iOS使用废弃的API
                        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
                    }
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
            
            basicButtonsContainer.addArrangedSubview(rowStackView)
        }
    }
    
    // 新增：创建科学计算器按钮
    private func setupScientificCalculatorButtons() {
        let scientificButtonTitles = [
            ["sin", "cos", "tan", "π"],
            ["log", "ln", "e^x", "x^2"],
            ["√x", "x^y", "1/x", "x!"],
            ["(", ")", "Rad", "Deg"]
        ]
        
        scientificButtonsContainer = UIStackView()
        scientificButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        scientificButtonsContainer.axis = .vertical
        scientificButtonsContainer.distribution = .fillEqually
        scientificButtonsContainer.spacing = 10
        scientificButtonsContainer.isHidden = true // 初始隐藏
        view.addSubview(scientificButtonsContainer)
        
        for row in scientificButtonTitles {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.distribution = .fillEqually
            rowStackView.spacing = 10
            
            for title in row {
                let button = createButton(withTitle: title)
                rowStackView.addArrangedSubview(button)
            }
            
            scientificButtonsContainer.addArrangedSubview(rowStackView)
        }
        
        // 设置约束
        NSLayoutConstraint.activate([
            scientificButtonsContainer.topAnchor.constraint(equalTo: controlButtonsContainer.bottomAnchor, constant: 10),
            scientificButtonsContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            scientificButtonsContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            scientificButtonsContainer.heightAnchor.constraint(equalToConstant: 180)
        ])
    }
    
    private func getButtonColor(forTitle title: String) -> UIColor {
        switch currentTheme {
        case .light:
            switch title {
            case "C", "±", "%", "π", "e^x", "√x", "x^2", "x^y", "1/x", "x!", "(", ")", "Rad", "Deg", "sin", "cos", "tan", "log", "ln":
                return .systemGray5
            case "÷", "×", "-", "+", "=":
                return .systemOrange
            case "设置", "历史", "模式", "主题":
                return .systemTeal
            default:
                return .systemGray6
            }
        case .dark:
            switch title {
            case "C", "±", "%", "π", "e^x", "√x", "x^2", "x^y", "1/x", "x!", "(", ")", "Rad", "Deg", "sin", "cos", "tan", "log", "ln":
                return .darkGray
            case "÷", "×", "-", "+", "=":
                return .orange
            case "设置", "历史", "模式", "主题":
                return .systemBlue
            default:
                return .gray
            }
        case .colorful:
            switch title {
            case "C", "±", "%":
                return UIColor(red: 0.9, green: 0.5, blue: 0.5, alpha: 1.0)
            case "÷", "×", "-", "+", "=":
                return UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
            case "π", "e^x", "√x", "x^2", "x^y", "1/x", "x!", "(", ")", "Rad", "Deg", "sin", "cos", "tan", "log", "ln":
                return UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1.0)
            case "设置", "历史", "模式", "主题":
                return UIColor(red: 0.4, green: 0.8, blue: 0.8, alpha: 1.0)
            default:
                return UIColor(red: 0.3, green: 0.3, blue: 0.6, alpha: 1.0)
            }
        }
    }
    
    private func getTextColor(forTitle title: String) -> UIColor {
        switch currentTheme {
        case .light, .dark:
            if title == "=" {
                return .white
            } else if ["设置", "历史", "模式", "主题"].contains(title) {
                return .white
            } else {
                return currentTheme == .light ? .black : .white
            }
        case .colorful:
            return .white
        }
    }
    
    // MARK: - 控制按钮操作
    
    @objc private func settingsButtonTapped() {
        let alertController = UIAlertController(title: "计算器设置", message: nil, preferredStyle: .actionSheet)
        
        // 仅保留必要的设置项
        alertController.addAction(UIAlertAction(title: "保存历史记录", style: .default) { _ in
            // 静默保存，不显示提示
            UserDefaults.standard.set(self.calculationHistory, forKey: "calculator_history")
        })
        
        alertController.addAction(UIAlertAction(title: "清除历史记录", style: .destructive) { _ in
            self.calculationHistory.removeAll()
            self.historyDisplayLabel.text = ""
        })
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = settingsButton
            popoverController.sourceRect = settingsButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    @objc private func historyButtonTapped() {
        if calculationHistory.isEmpty {
            displayTemporaryMessage("暂无计算历史")
            return
        }
        
        let alertController = UIAlertController(title: "计算历史", message: nil, preferredStyle: .actionSheet)
        
        // 添加历史记录
        for (index, historyItem) in calculationHistory.enumerated().reversed() {
            alertController.addAction(UIAlertAction(title: historyItem, style: .default) { [weak self] _ in
                // 点击历史记录项时，将其作为当前输入
                if let result = historyItem.components(separatedBy: " = ").last {
                    self?.currentInput = result
                    self?.updateDisplay()
                }
            })
            
            // 限制显示的历史记录数量
            if index == 0 {
                break
            }
        }
        
        alertController.addAction(UIAlertAction(title: "清除历史", style: .destructive) { [weak self] _ in
            self?.calculationHistory.removeAll()
            self?.historyDisplayLabel.text = ""
        })
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = historyButton
            popoverController.sourceRect = historyButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    @objc private func modeToggleButtonTapped() {
        // 切换计算器模式
        currentMode = currentMode == .basic ? .scientific : .basic
        
        // 保存用户偏好
        UserDefaults.standard.set(currentMode == .scientific, forKey: "scientific_mode_enabled")
        UserDefaults.standard.synchronize()
        
        toggleCalculatorMode()
        displayTemporaryMessage(currentMode == .basic ? "基础模式" : "科学模式")
    }
    
    // 新增：切换计算器模式
    private func toggleCalculatorMode() {
        // 停用之前的约束
        basicToControlConstraint.isActive = false
        basicToScientificConstraint.isActive = false
        
        switch currentMode {
        case .basic:
            scientificButtonsContainer.isHidden = true
            basicToControlConstraint.isActive = true
        case .scientific:
            scientificButtonsContainer.isHidden = false
            basicToScientificConstraint.isActive = true
        }
        
        // 强制布局更新
        view.layoutIfNeeded()
    }
    
    @objc private func themeButtonTapped() {
        let alertController = UIAlertController(title: "选择主题", message: nil, preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: "浅色主题", style: .default) { [weak self] _ in
            self?.currentTheme = .light
            self?.applyTheme()
            UserDefaults.standard.set("light", forKey: "calculator_theme")
            UserDefaults.standard.synchronize()
        })
        
        alertController.addAction(UIAlertAction(title: "深色主题", style: .default) { [weak self] _ in
            self?.currentTheme = .dark
            self?.applyTheme()
            UserDefaults.standard.set("dark", forKey: "calculator_theme")
            UserDefaults.standard.synchronize()
        })
        
        alertController.addAction(UIAlertAction(title: "彩色主题", style: .default) { [weak self] _ in
            self?.currentTheme = .colorful
            self?.applyTheme()
            UserDefaults.standard.set("colorful", forKey: "calculator_theme")
            UserDefaults.standard.synchronize()
        })
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = themeButton
            popoverController.sourceRect = themeButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    // MARK: - 按钮操作
    
    @objc private func buttonTapped(_ sender: UIButton) {
        guard let title = sender.currentTitle else { return }
        
        // 特殊序列变量保留但不显示任何提示
        if ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"].contains(title) {
            specialSequence.append(title)
            
            // 保持序列最多4位
            if specialSequence.count > 4 {
                specialSequence.removeFirst()
            }
            
            // 检查是否匹配特殊序列，但不显示提示
            if specialSequence == correctSpecialSequence {
                // 静默触发检查
                silentCheckForDisguiseMode()
                specialSequence.removeAll() // 重置序列
            }
        }
        
        // 处理科学计算器按钮 - 放在主线程立即执行
        switch title {
        case "sin", "cos", "tan", "log", "ln", "e^x", "x^2", "√x", "x^y", "1/x", "x!", "π", "(", ")", "Rad", "Deg":
            handleScientificOperation(title)
            return
        default:
            break
        }
        
        // 原有的计算器功能 - 直接更新UI
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
            // 立即更新显示
            displayLabel.text = currentInput
            
        case ".":
            if shouldResetInput {
                currentInput = "0."
                shouldResetInput = false
            } else if !currentInput.contains(".") {
                // 确保只有一个小数点
                currentInput += "."
            }
            // 立即更新显示
            displayLabel.text = currentInput
            
        case "C":
            // 清除所有
            currentInput = ""
            firstOperand = nil
            operation = nil
            historyDisplayLabel.text = ""
            // 立即更新显示
            displayLabel.text = "0"
            
        case "±":
            // 正负号切换
            if !currentInput.isEmpty {
                if currentInput.hasPrefix("-") {
                    currentInput.removeFirst()
                } else {
                    currentInput = "-" + currentInput
                }
                // 立即更新显示
                displayLabel.text = currentInput
            }
            
        case "%":
            // 百分比
            if let value = Double(currentInput) {
                currentInput = String(value / 100)
                // 立即更新显示
                updateDisplay()
            }
            
        case "÷", "×", "-", "+":
            if let value = Double(currentInput) {
                // 如果已经有一个操作数，则立即执行计算
                if let firstOp = firstOperand, let op = operation {
                    let result = calculate(firstOp, value, op)
                    
                    // 添加到历史记录
                    addToHistory("\(formatResult(firstOp)) \(op) \(formatResult(value)) = \(formatResult(result))")
                    
                    currentInput = formatResult(result)
                    // 立即更新显示
                    displayLabel.text = currentInput
                }
                
                firstOperand = Double(currentInput)
                operation = title
                shouldResetInput = true
                
                // 立即更新历史显示
                historyDisplayLabel.text = "\(currentInput) \(title)"
            }
            
        case "=":
            if let firstOp = firstOperand, let op = operation, let secondOp = Double(currentInput) {
                let result = calculate(firstOp, secondOp, op)
                
                // 添加到历史记录
                addToHistory("\(formatResult(firstOp)) \(op) \(formatResult(secondOp)) = \(formatResult(result))")
                
                currentInput = formatResult(result)
                // 立即更新显示
                displayLabel.text = currentInput
                
                // 立即更新历史显示
                historyDisplayLabel.text = "\(formatResult(firstOp)) \(op) \(formatResult(secondOp)) = \(formatResult(result))"
                
                // 重置操作
                firstOperand = nil
                operation = nil
                shouldResetInput = true
            }
            
        default:
            break
        }
    }
    
    // 新增：处理科学计算器操作
    private func handleScientificOperation(_ operation: String) {
        guard let value = Double(currentInput) else {
            if operation == "π" {
                currentInput = formatResult(Double.pi)
                updateDisplay()
            }
            return
        }
        
        var result: Double = 0
        var operationText = ""
        
        switch operation {
        case "sin":
            result = sin(value * .pi / 180)
            operationText = "sin(\(formatResult(value))°)"
        case "cos":
            result = cos(value * .pi / 180)
            operationText = "cos(\(formatResult(value))°)"
        case "tan":
            result = tan(value * .pi / 180)
            operationText = "tan(\(formatResult(value))°)"
        case "log":
            if value > 0 {
                result = log10(value)
                operationText = "log(\(formatResult(value)))"
            } else {
                displayTemporaryMessage("无效输入")
                return
            }
        case "ln":
            if value > 0 {
                result = log(value)
                operationText = "ln(\(formatResult(value)))"
            } else {
                displayTemporaryMessage("无效输入")
                return
            }
        case "e^x":
            result = exp(value)
            operationText = "e^\(formatResult(value))"
        case "x^2":
            result = pow(value, 2)
            operationText = "\(formatResult(value))²"
        case "√x":
            if value >= 0 {
                result = sqrt(value)
                operationText = "√\(formatResult(value))"
            } else {
                displayTemporaryMessage("无效输入")
                return
            }
        case "1/x":
            if value != 0 {
                result = 1 / value
                operationText = "1/\(formatResult(value))"
            } else {
                displayTemporaryMessage("除数不能为零")
                return
            }
        case "π":
            result = Double.pi
            operationText = "π"
        case "x!":
            if value >= 0 && value == floor(value) && value <= 20 {
                result = factorial(Int(value))
                operationText = "\(Int(value))!"
            } else {
                displayTemporaryMessage("无效输入，需要小于21的非负整数")
                return
            }
        default:
            return
        }
        
        // 添加到历史记录
        addToHistory("\(operationText) = \(formatResult(result))")
        
        // 更新显示
        historyDisplayLabel.text = "\(operationText) ="
        currentInput = formatResult(result)
        updateDisplay()
        shouldResetInput = true
    }
    
    // 新增：阶乘计算
    private func factorial(_ n: Int) -> Double {
        if n <= 1 {
            return 1
        }
        return Double(n) * factorial(n - 1)
    }
    
    // 新增：添加历史记录
    private func addToHistory(_ record: String) {
        calculationHistory.append(record)
        
        // 限制历史记录数量
        if calculationHistory.count > maxHistoryItems {
            calculationHistory.removeFirst()
        }
    }
    
    // MARK: - 特殊交互
    
    @objc private func longPressDetected(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // 静默触发检查
            silentCheckForDisguiseMode()
        }
    }
    
    @objc private func doubleTapDetected(_ gesture: UITapGestureRecognizer) {
        // 静默触发检查，不显示提示
        silentCheckForDisguiseMode()
    }
    
    // 修改服务器检查方法，不显示提示
    private func silentCheckForDisguiseMode() {
        // 静默触发检查，不显示任何提示信息
        ServerController.shared.checkDisguiseMode { [weak self] shouldShowRealApp in
            if shouldShowRealApp {
                DispatchQueue.main.async {
                    self?.switchToRealApp()
                }
            }
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
    
    // 缺失方法1: 创建按钮
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
    
    // 缺失方法2: 计算函数
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
    
    // 缺失方法3: 格式化结果
    private func formatResult(_ result: Double) -> String {
        // 格式化结果，如果是整数则不显示小数点
        return result.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(result)) : String(result)
    }
    
    // 优化显示更新方法，加快处理长数字的速度
    private func updateDisplay() {
        if currentInput.isEmpty {
            displayLabel.text = "0"
            return
        }
        
        // 简化长数字处理，避免复杂格式化导致的延迟
        let maxDisplayLength = 12
        
        if currentInput.count > maxDisplayLength {
            // 只在确实需要时才使用科学计数法
            if let value = Double(currentInput), abs(value) > 999999999999 || abs(value) < 0.000000000001 {
                let formatter = NumberFormatter()
                formatter.numberStyle = .scientific
                formatter.maximumFractionDigits = 6
                formatter.exponentSymbol = "e"
                
                if let formattedValue = formatter.string(from: NSNumber(value: value)) {
                    displayLabel.text = formattedValue
                    return
                }
            }
        }
        
        // 默认直接显示
        displayLabel.text = currentInput
    }
    
    // 优化按钮按下效果，减少动画时间提升响应速度
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.05) { // 从0.1秒减少到0.05秒
            sender.transform = CGAffineTransform(scaleX: 0.97, y: 0.97) // 缩小幅度减小
            sender.alpha = 0.95 // 透明度变化减小
        }
    }
    
    // 优化按钮释放效果，减少动画时间
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.05) { // 从0.1秒减少到0.05秒
            sender.transform = .identity
            sender.alpha = 1.0
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