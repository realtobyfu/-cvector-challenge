enum BuildFlags {
    static var isBYOEnabled: Bool {
#if DEBUG
        return true
#else
        return false
#endif
    }
}
