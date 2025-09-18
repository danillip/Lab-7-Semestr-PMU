import UIKit

/// тут придумайте фон паралакс чтобы прикольно было переливалось через АНИМАЦИИ
final class ParallaxLayerView: UIView {

    // множитель скорости (0.3 дальний, 0.6 средний, 1.0 ближний)
    private let speedMultiplier: CGFloat

    // тайтлы чтобы циклить фон
    private let tileA = UIView()
    private let tileB = UIView()

    // вот из за этого и не работало
    private var offsetY: CGFloat = 0

    init(speedMultiplier: CGFloat,
         topColor: UIColor,
         bottomColor: UIColor,
         alpha: CGFloat) {
        self.speedMultiplier = speedMultiplier
        super.init(frame: .zero)

        isUserInteractionEnabled = false
        alpha == 1 ? () : (self.alpha = alpha)

        // Что то типо градиента по крайней мере так задумывалось
        func makeGradientView() -> UIView {
            let v = UIView()
            v.isUserInteractionEnabled = false
            let g = CAGradientLayer()
            g.colors = [topColor.cgColor, bottomColor.cgColor]
            g.startPoint = CGPoint(x: 0.5, y: 0.0)
            g.endPoint   = CGPoint(x: 0.5, y: 1.0)
            g.frame = v.bounds
            v.layer.insertSublayer(g, at: 0)
            v.layer.masksToBounds = true
            // на ресайз
            v.layer.setNeedsLayout()
            v.layer.layoutSublayers()
            return v
        }

        tileA.addGradient(topColor: topColor, bottomColor: bottomColor)
        tileB.addGradient(topColor: topColor, bottomColor: bottomColor)

        addSubview(tileA)
        addSubview(tileB)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Правки от Д Каждый тайл высотой с сам слой чтобы шов был ровны
        tileA.frame = bounds
        tileB.frame = bounds.offsetBy(dx: 0, dy: -bounds.height)
        (tileA.layer.sublayers?.first as? CAGradientLayer)?.frame = tileA.bounds
        (tileB.layer.sublayers?.first as? CAGradientLayer)?.frame = tileB.bounds
    }

    /// Апдейт позиции слоя
    /// - Parameters:
    ///   - baseSpeed: базовая скорость мира (px/sec)
    ///   - delta: прошедшее время (сек)
    func update(baseSpeed: CGFloat, delta: CGFloat) {
        guard bounds.height > 1 else { return }

        // на сколько прокрутить за кадр
        let dy = baseSpeed * speedMultiplier * delta
        offsetY += dy

        tileA.frame.origin.y += dy
        tileB.frame.origin.y += dy

        // если тайл полностью ушёл вниз перекидываем его наверх
        let h = bounds.height
        if tileA.frame.minY >= h { tileA.frame.origin.y = tileB.frame.minY - h }
        if tileB.frame.minY >= h { tileB.frame.origin.y = tileA.frame.minY - h }
    }
}

// TODO: - Утилита для градиента
private extension UIView {
    func addGradient(topColor: UIColor, bottomColor: UIColor) {
        let g = CAGradientLayer()
        g.colors = [topColor.cgColor, bottomColor.cgColor]
        g.startPoint = CGPoint(x: 0.5, y: 0.0)
        g.endPoint   = CGPoint(x: 0.5, y: 1.0)
        g.frame = bounds
        layer.insertSublayer(g, at: 0)
        layer.masksToBounds = true
    }
}
