<?php
// 这是一个简单的测试脚本，用于模拟设备UDID接收和重定向功能

// 接收来自设备的XML数据
$data = file_get_contents('php://input');

// 如果有XML数据
if ($data) {
    // 解析XML数据
    $plist = simplexml_load_string($data);
    
    // 提取UDID
    $UDID = (string)$plist->dict->string[1];
    
    // 记录接收到的UDID (可选)
    file_put_contents('udid_log.txt', date('Y-m-d H:i:s') . " - Received UDID: $UDID\n", FILE_APPEND);
    
    // 重定向回AppFlex应用，使用appflex URL Scheme
    header('HTTP/1.1 301 Moved Permanently');
    header("Location: appflex://udid/$UDID");
    exit();
} else {
    // 如果没有收到数据，显示一个测试页面
    echo '<!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>UDID测试</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; }
            .button { 
                display: inline-block;
                background-color: #4CAF50;
                color: white;
                padding: 10px 20px;
                text-align: center;
                text-decoration: none;
                font-size: 16px;
                margin: 10px 2px;
                cursor: pointer;
                border-radius: 4px;
            }
            .note { color: #666; font-size: 14px; margin-top: 20px; }
        </style>
    </head>
    <body>
        <h1>UDID测试页面</h1>
        <p>点击下面的按钮测试安装描述文件并获取UDID：</p>
        <a href="udid.mobileconfig" class="button">安装描述文件</a>
        
        <div class="note">
            <p><strong>测试说明：</strong></p>
            <ol>
                <li>点击上方按钮安装描述文件</li>
                <li>在设备上按照提示安装描述文件</li>
                <li>安装完成后，系统将收集UDID并重定向回AppFlex应用</li>
                <li>如果一切设置正确，您应该会自动回到AppFlex应用</li>
            </ol>
        </div>
        
        <div class="note">
            <p><strong>排查提示：</strong></p>
            <ol>
                <li>确保AppFlex应用已经安装</li>
                <li>确保AppFlex应用已正确配置URL Scheme: appflex</li>
                <li>重定向URL将是: appflex://udid/您的设备UDID</li>
            </ol>
        </div>
    </body>
    </html>';
}
?> 