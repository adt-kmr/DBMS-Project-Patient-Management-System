// middlewares/verifyToken.js
import axios from 'axios';

// const AUTH_URL = "http://auth:3000/verify";
const AUTH_URL = "http://0.0.0.0:3000/verify" 

export const verifyToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Missing or invalid Authorization header' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const response = await axios.post(AUTH_URL, { token });

    if (!response.data.valid) {
      return res.status(401).json({ message: 'Token invalid' });
    }

    // Attach the decoded user object to req.user
    req.user = response.data.user; // This will be: { userId: 3 }
    next();
  } catch (err) {
    console.error('[verifyToken] Error:', err.message);
    res.status(401).json({ message: 'Token verification failed' });
  }
};
