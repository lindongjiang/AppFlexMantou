// StoreModels.swift
// 存储商店和资源部分共享的数据模型
// Created by AppFlex Developer on 2025/4/28.

import UIKit

/// 资源卡片模型，用于展示内容资源和应用资源
struct ResourceCard {
    let name: String
    let url: String
    let imageURL: String? // 资源图片URL
}

/// 资源卡片单元格，用于CollectionView中显示资源
class ResourceCollectionViewCell: UICollectionViewCell {
    
    private let nameLabel = UILabel()
    private let urlLabel = UILabel()
    private let iconImageView = UIImageView()
    private let resourceImageView = UIImageView() // 资源图片视图
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        
        // 添加阴影效果
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        layer.masksToBounds = false
        
        // 资源图片
        resourceImageView.translatesAutoresizingMaskIntoConstraints = false
        resourceImageView.contentMode = .scaleAspectFill
        resourceImageView.layer.cornerRadius = 8
        resourceImageView.layer.masksToBounds = true
        resourceImageView.backgroundColor = .systemGray6
        contentView.addSubview(resourceImageView)
        
        // 图标
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue
        iconImageView.image = UIImage(systemName: "globe")
        contentView.addSubview(iconImageView)
        
        // 资源名称标签
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 2
        contentView.addSubview(nameLabel)
        
        // URL标签
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.font = UIFont.systemFont(ofSize: 12)
        urlLabel.textColor = .secondaryLabel
        urlLabel.numberOfLines = 1
        contentView.addSubview(urlLabel)
        
        NSLayoutConstraint.activate([
            // 资源图片约束
            resourceImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            resourceImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            resourceImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            resourceImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // 图标约束
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.topAnchor.constraint(equalTo: resourceImageView.bottomAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // 名称标签约束
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: resourceImageView.bottomAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // URL标签约束
            urlLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            urlLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            urlLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    func configure(with resource: ResourceCard) {
        nameLabel.text = resource.name
        urlLabel.text = resource.url
        
        // 设置图片
        if let imageURLString = resource.imageURL, !imageURLString.isEmpty, let imageURL = URL(string: imageURLString) {
            // 使用URLSession加载图片
            URLSession.shared.dataTask(with: imageURL) { [weak self] data, response, error in
                guard let self = self, 
                      let data = data, 
                      let image = UIImage(data: data) else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.resourceImageView.image = image
                }
            }.resume()
        } else {
            // 设置默认图片
            resourceImageView.image = UIImage(systemName: "photo")
            resourceImageView.tintColor = .systemGray4
            resourceImageView.contentMode = .center
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        urlLabel.text = nil
        iconImageView.image = UIImage(systemName: "globe")
        resourceImageView.image = nil
    }
} 