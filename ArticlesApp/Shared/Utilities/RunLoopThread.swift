//
//  RunLoopThread.swift
//  ArticlesApp
//
//  Created by Edwinps on 23/2/26.
//

import Foundation

final class RunLoopThread: NSObject {
    private let thread: Thread
    private let ready = DispatchSemaphore(value: 0)

    init(name: String) {
        thread = Thread { [ready] in
            Thread.current.name = name

            let runLoop = RunLoop.current
            runLoop.add(Port(), forMode: .default)

            ready.signal()
            runLoop.run()
        }
        super.init()
        thread.start()
        ready.wait()
    }

    func perform(_ block: @escaping () -> Void) {
        (self as NSObject).perform(#selector(RunLoopThread.runBlock(_:)), on: thread, with: block, waitUntilDone: false)
    }

    @objc private func runBlock(_ block: Any) {
        (block as? () -> Void)?()
    }
}
