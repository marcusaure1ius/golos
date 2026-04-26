import Testing
import Foundation
@testable import golos

@Suite struct AudioWriterTests {
    @Test func flushReturnsAfterAllPendingWrites() async throws {
        // Создаём pipe и читаем с другого конца.
        var fds: [Int32] = [0, 0]
        #expect(pipe(&fds) == 0)
        let readFd = fds[0]
        let writeFd = fds[1]

        let writer = AudioWriter(fd: writeFd)
        let payload = Data(repeating: 0xAB, count: 1024)
        for _ in 0..<10 {
            await writer.enqueue(payload)
        }
        await writer.flush()

        // После flush — все 10 * 1024 байт должны быть прочитываемы синхронно.
        let readFile = FileHandle(fileDescriptor: readFd, closeOnDealloc: true)
        // Запросим 10*1024 байт — pipe-буфер должен их содержать.
        let buf = readFile.availableData
        #expect(buf.count == 10 * 1024)

        await writer.close()
    }

    @Test func enqueueAfterCloseIsNoop() async {
        var fds: [Int32] = [0, 0]
        #expect(pipe(&fds) == 0)
        let writer = AudioWriter(fd: fds[1])
        await writer.close()
        await writer.enqueue(Data([1, 2, 3]))  // не должно крашить
        close(fds[0])
    }
}
