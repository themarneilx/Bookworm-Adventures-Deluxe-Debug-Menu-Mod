#!/usr/bin/env python3
"""Install or restore the Bookworm Adventures Deluxe battle debug menu."""

import argparse
from hashlib import sha256
import os
from pathlib import Path
import stat
import struct
from tempfile import NamedTemporaryFile


STOCK_HASH = "76e729187920c41de3e75a740e8277aa0206423b12bec6781e776bfd88fa2b2f"
ARCHIVE_NAME = "main.pak"
BACKUP_NAME = "main.pak.bookworm-debug.original"
BOARD_NAME = b"scripts/board.luc"
PAK_MASK = bytes(value ^ 0xF7 for value in range(256))
PAK_HEADER = bytes.fromhex("c04ac0ba00000000")

# Offsets in the stock Board.luc matched by STOCK_HASH.
BOARD_LINES_OFFSET = 58
BOARD_CONSTANTS_OFFSET = 270
BOARD_PROTOTYPES_OFFSET = 540
BOARD_CODE_OFFSET = 3670
BOARD_REGISTRATION_PC = 41


def digest(data: bytes) -> str:
    return sha256(data).hexdigest()


def read_int(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def pack_int(value: int) -> bytes:
    return struct.pack("<I", value)


def locate_board(data: bytes) -> tuple[int, int, int]:
    if not data.startswith(PAK_HEADER):
        raise ValueError("Unexpected main.pak header")
    cursor = len(PAK_HEADER)
    contents_length = 0
    board = None
    while data[cursor] == 0:
        name_length = data[cursor + 1]
        name_start = cursor + 2
        size_offset = name_start + name_length
        name = data[name_start:size_offset].lower().replace(b"\\", b"/")
        member_length = read_int(data, size_offset)
        if name == BOARD_NAME:
            board = size_offset, contents_length, member_length
        contents_length += member_length
        cursor = size_offset + 12
    if data[cursor] != 0x80 or cursor + 1 + contents_length != len(data) or board is None:
        raise ValueError("Unexpected main.pak directory")
    size_offset, relative_offset, length = board
    return size_offset, cursor + 1 + relative_offset, length


def patch_board(board: bytes, source: bytes) -> bytes:
    if not source or not source.isascii() or b"\0" in source:
        raise ValueError("debug_menu.lua must contain ASCII Lua source")
    line_count = read_int(board, BOARD_LINES_OFFSET)
    constant_count = read_int(board, BOARD_CONSTANTS_OFFSET)
    instruction_count = read_int(board, BOARD_CODE_OFFSET)
    line_at_registration = BOARD_LINES_OFFSET + 4 + BOARD_REGISTRATION_PC * 4
    code_at_registration = BOARD_CODE_OFFSET + 4 + BOARD_REGISTRATION_PC * 4
    if (
        (line_count, constant_count, instruction_count) != (50, 18, 50)
        or read_int(board, code_at_registration) != (5 | (16 << 6))
    ):
        raise ValueError("Unexpected Board.luc structure")

    strings = (b"pcall", b"loadstring", source)
    constants = b"".join(
        b"\x05" + pack_int(len(value) + 1) + value + b"\0" for value in strings
    )
    # Compile and call the mod through Lua before registering the board widget.
    # These are the stock VM's GETGLOBAL, LOADK, and CALL instructions.
    instructions = (
        5 | (constant_count << 6),
        5 | (1 << 24) | ((constant_count + 1) << 6),
        1 | (2 << 24) | ((constant_count + 2) << 6),
        27 | (1 << 24) | (2 << 15) | (2 << 6),
        27 | (2 << 15) | (1 << 6),
    )
    return (
        board[:BOARD_LINES_OFFSET]
        + pack_int(line_count + len(instructions))
        + board[BOARD_LINES_OFFSET + 4:line_at_registration]
        + board[line_at_registration:line_at_registration + 4] * len(instructions)
        + board[line_at_registration:BOARD_CONSTANTS_OFFSET]
        + pack_int(constant_count + len(strings))
        + board[BOARD_CONSTANTS_OFFSET + 4:BOARD_PROTOTYPES_OFFSET]
        + constants
        + board[BOARD_PROTOTYPES_OFFSET:BOARD_CODE_OFFSET]
        + pack_int(instruction_count + len(instructions))
        + board[BOARD_CODE_OFFSET + 4:code_at_registration]
        + b"".join(pack_int(instruction) for instruction in instructions)
        + board[code_at_registration:]
    )


def build_archive(stock: bytes, source: bytes) -> bytes:
    if digest(stock) != STOCK_HASH:
        raise ValueError("main.pak does not match the supported stock archive")
    data = stock.translate(PAK_MASK)
    size_offset, start, length = locate_board(data)
    board = patch_board(data[start:start + length], source)
    updated = (
        data[:size_offset] + pack_int(len(board)) + data[size_offset + 4:start]
        + board + data[start + length:]
    )
    return updated.translate(PAK_MASK)


def save_backup(path: Path, original: bytes) -> None:
    try:
        stream = path.open("xb")
    except FileExistsError:
        if path.is_symlink() or path.read_bytes() != original:
            raise ValueError("The existing backup does not match the supported stock archive")
        return
    try:
        with stream:
            stream.write(original)
            stream.flush()
            os.fsync(stream.fileno())
    except OSError:
        path.unlink()
        raise
    if path.read_bytes() != original:
        raise OSError("The original archive backup could not be verified")


def replace_archive(path: Path, current: bytes, updated: bytes) -> None:
    mode = stat.S_IMODE(path.stat().st_mode)
    with NamedTemporaryFile(prefix=".bookworm-debug-", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(updated)
            stream.flush()
            os.fsync(stream.fileno())
        except OSError:
            stream.close()
            temporary.unlink()
            raise
    try:
        temporary.chmod(mode)
        if path.is_symlink() or path.read_bytes() != current:
            raise ValueError("main.pak changed during setup. Close the game and try again.")
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)
    if path.read_bytes() != updated:
        raise OSError("The written archive could not be verified")


def configure(game_dir: Path, restore: bool) -> str:
    archive = game_dir / ARCHIVE_NAME
    backup = game_dir / BACKUP_NAME
    if archive.is_symlink() or backup.is_symlink():
        raise ValueError("Choose a game folder with a regular main.pak and backup")
    current = archive.read_bytes()
    stock = digest(current) == STOCK_HASH
    if restore and stock:
        return "The original archive is already active."

    original = backup.read_bytes() if backup.exists() else None
    if original is not None and digest(original) != STOCK_HASH:
        raise ValueError("The original archive backup failed its checksum check")

    if restore:
        if original is None:
            raise ValueError(f"Restore requires a verified {BACKUP_NAME}")
        replace_archive(archive, current, original)
        return "Original archive restored."

    if not stock and original is None:
        raise ValueError("Install requires the supported original main.pak")
    source = Path(__file__).with_name("debug_menu.lua").read_bytes()
    updated = build_archive(current if stock else original, source)
    if not stock:
        if current == updated:
            return "This version of the debug menu is already installed."
        raise ValueError("Restore the original archive before installing this version")

    save_backup(backup, current)
    replace_archive(archive, current, updated)
    return f"Debug menu installed. Original saved as {backup.name}."


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("game_dir", type=Path, help="game folder containing main.pak")
    parser.add_argument("--restore", action="store_true", help="restore the backed-up main.pak")
    args = parser.parse_args()
    try:
        print(configure(args.game_dir.resolve(), args.restore))
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
