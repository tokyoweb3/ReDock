import CoreGraphics
import Testing
@testable import MWM

@Suite("Window calculations")
struct WindowCalculationTests {
    let screen = CGRect(x: 0, y: 25, width: 1920, height: 1055)
    let window = CGRect(x: 100, y: 100, width: 800, height: 600)

    private func params(action: WindowAction) -> CalculationParameters {
        CalculationParameters(windowFrame: window, visibleFrame: screen, action: action)
    }

    // MARK: - Half calculations

    @Test("Left half fills left side of screen")
    func leftHalf() {
        let result = HalfCalculation().calculate(params(action: .leftHalf))
        #expect(result.origin.x == 0)
        #expect(result.origin.y == 25)
        #expect(result.width == 960)
        #expect(result.height == 1055)
    }

    @Test("Right half fills right side of screen")
    func rightHalf() {
        let result = HalfCalculation().calculate(params(action: .rightHalf))
        #expect(result.origin.x == 960)
        #expect(result.origin.y == 25)
        #expect(result.width == 960)
        #expect(result.height == 1055)
    }

    @Test("Top half fills top of screen")
    func topHalf() {
        let result = HalfCalculation().calculate(params(action: .topHalf))
        #expect(result.origin.x == 0)
        #expect(result.origin.y == 25)
        #expect(result.width == 1920)
        #expect(result.height == 527)
    }

    @Test("Bottom half fills bottom of screen")
    func bottomHalf() {
        let result = HalfCalculation().calculate(params(action: .bottomHalf))
        #expect(result.origin.x == 0)
        #expect(result.width == 1920)
        #expect(result.height == 527)
    }

    @Test("Left two-thirds fills the left 66 percent")
    func leftTwoThirds() {
        let result = FractionCalculation().calculate(params(action: .leftTwoThirds))
        #expect(result.origin.x == 0)
        #expect(result.origin.y == 25)
        #expect(result.width == 1280)
        #expect(result.height == 1055)
    }

    @Test("Bottom third fills the lower 33 percent")
    func bottomThird() {
        let result = FractionCalculation().calculate(params(action: .bottomThird))
        #expect(result.origin.x == 0)
        #expect(result.width == 1920)
        #expect(result.height == 351)
        #expect(result.origin.y == 729)
    }

    // MARK: - Quarter calculations

    @Test("Top left fills upper-left quarter")
    func topLeft() {
        let result = QuarterCalculation().calculate(params(action: .topLeft))
        #expect(result.origin.x == 0)
        #expect(result.origin.y == 25)
        #expect(result.width == 960)
        #expect(result.height == 527)
    }

    @Test("Bottom right fills lower-right quarter")
    func bottomRight() {
        let result = QuarterCalculation().calculate(params(action: .bottomRight))
        #expect(result.origin.x == 960)
        #expect(result.width == 960)
        #expect(result.height == 527)
    }

    // MARK: - Center

    @Test("Center preserves window size and centers on screen")
    func center() {
        let result = CenterCalculation().calculate(params(action: .center))
        #expect(result.width == 800)
        #expect(result.height == 600)
        #expect(result.origin.x == 560)  // (1920 - 800) / 2
    }

    @Test("Center shrinks window if larger than screen")
    func centerClampsLargeWindow() {
        let bigWindow = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let p = CalculationParameters(windowFrame: bigWindow, visibleFrame: screen, action: .center)
        let result = CenterCalculation().calculate(p)
        #expect(result.width == 1920)
        #expect(result.height == 1055)
    }

    // MARK: - Maximize

    @Test("Maximize fills entire visible screen")
    func maximize() {
        let result = MaximizeCalculation().calculate(params(action: .maximize))
        #expect(result == screen)
    }

    // MARK: - Resize

    @Test("Increase makes window larger")
    func increase() {
        let result = ResizeCalculation().calculate(params(action: .increase))
        #expect(result.width > window.width)
        #expect(result.height > window.height)
    }

    @Test("Decrease makes window smaller")
    func decrease() {
        let result = ResizeCalculation().calculate(params(action: .decrease))
        #expect(result.width < window.width)
        #expect(result.height < window.height)
    }

    @Test("Decrease respects minimum size")
    func decreaseMinimum() {
        let tinyWindow = CGRect(x: 100, y: 100, width: 100, height: 100)
        let p = CalculationParameters(windowFrame: tinyWindow, visibleFrame: screen, action: .decrease)
        let result = ResizeCalculation().calculate(p)
        #expect(result.width >= 100)
        #expect(result.height >= 100)
    }

    // MARK: - Multi-screen calculations

    @Test("Left half on offset screen uses correct origin")
    func leftHalfOffsetScreen() {
        let secondScreen = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
        let p = CalculationParameters(windowFrame: window, visibleFrame: secondScreen, action: .leftHalf)
        let result = HalfCalculation().calculate(p)
        #expect(result.origin.x == 1920)
        #expect(result.width == 1280)
        #expect(result.height == 1440)
    }

    // MARK: - CalculationFactory

    @Test("Factory returns correct calculation for each action")
    func factoryMapping() {
        #expect(CalculationFactory.calculation(for: .leftHalf) is HalfCalculation)
        #expect(CalculationFactory.calculation(for: .leftTwoThirds) is FractionCalculation)
        #expect(CalculationFactory.calculation(for: .topLeft) is QuarterCalculation)
        #expect(CalculationFactory.calculation(for: .center) is CenterCalculation)
        #expect(CalculationFactory.calculation(for: .maximize) is MaximizeCalculation)
        #expect(CalculationFactory.calculation(for: .increase) is ResizeCalculation)
        #expect(CalculationFactory.calculation(for: .toggleFullScreen) == nil)
        #expect(CalculationFactory.calculation(for: .nextScreen) == nil)
    }
}
