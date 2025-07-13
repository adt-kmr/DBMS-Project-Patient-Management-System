import {Request, Response, NextFunction} from "express";

const CheckBADJSON = (err: any, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof SyntaxError && 'body' in err) {
    return res.status(400).json({ error: 'Invalid JSON' });
}
next();
}

export default CheckBADJSON;