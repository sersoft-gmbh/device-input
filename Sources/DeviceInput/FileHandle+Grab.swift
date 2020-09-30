import Cinput
import SystemPackage

#if os(Linux)
@_implementationOnly import Glibc
#endif

extension Errno {
    fileprivate static var current: Errno { Errno(rawValue: errno) }
}

// Results in errno if i == -1
fileprivate func valueOrErrno<I: FixedWidthInteger>(_ i: I) -> Result<I, Errno> {
    i == -1 ? .failure(.current) : .success(i)
}

fileprivate func valueOrErrno<I: FixedWidthInteger>(
    retryOnInterrupt: Bool, _ f: () -> I
) -> Result<I, Errno> {
    repeat {
        switch valueOrErrno(f()) {
        case .success(let r): return .success(r)
        case .failure(let err) where retryOnInterrupt && err == .interrupted: continue
        case .failure(let err): return .failure(err)
        }
    } while true
}

extension FileDescriptor {
    func takeGrab() throws {
        try valueOrErrno(retryOnInterrupt: true) {
            grab_device(rawValue)
        }.map { _ in }.get()
    }

    func releaseGrab() throws {
        try valueOrErrno(retryOnInterrupt: true) {
            release_device(rawValue)
        }.map { _ in }.get()
    }
}
