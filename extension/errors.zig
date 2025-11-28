pub const ParseError = error{
    ParseFailed,
    InvalidList,
    InvalidListItem,
    InvalidString,
    OutOfMemory,
};