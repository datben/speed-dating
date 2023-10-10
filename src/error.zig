const zap = @import("zap");

pub const ErrorSD = error{ BadRequest, InternalServerError, UserNotFound, NotEnoughtToken, WrongPassword };

pub fn send_error(r: zap.SimpleRequest, code: u32, err: anyerror) !void {
    r.setStatus(@enumFromInt(code));
    return r.sendBody(@errorName(err));
}
