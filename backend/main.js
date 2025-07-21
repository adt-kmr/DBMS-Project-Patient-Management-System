var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import express from "express";
import Log from "./logger.js";
import { PrismaClient } from './generated/prisma/client.js';
import { verifyToken } from './middlewares/verifyToken.js';
import CheckBADJSON from "./middlewares/JsonErrorChecker.js";
const prisma = new PrismaClient();
const app = express();
const router = express.Router();
app.use(express.json());
//AUTH URL
/////////////////////////////////////////////////////////
const auth_url = "http://auth:3000/login"; ///////////////
/////////////////////////////////////////////////////////
router.get("/", (req, res) => {
    Log("/", "GET", 200);
    res.send("HALO");
    // res.type("json");
});
// interface AuthenticatedRequest extends Request {
//   user?: {
//     userId: number;
//     email: string;
//     role: string;
//   };
// }
router.post("/login", (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    Log("/login", "POST", 200);
    const { email, password } = req.body;
    if (!email || !password) {
        return res.status(400).json({
            error: "Bad Payload."
        });
    }
    try {
        const Response = yield fetch(auth_url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ email, password })
        });
        if (!Response.ok) {
            console.error("Auth container responded with error:", Response.status);
            return res.status(500).json({ error: "Auth container error." });
        }
        const json = yield Response.json();
        console.log("Response from auth container: ", json);
        return res.json(json);
    }
    catch (e) {
        console.error("Some problem occurred while contacting auth container. Error:", e);
        return res.status(500).json({
            error: "Unable to login, Some error occurred in backend.",
            details: e
        });
    }
}));
router.get("/patients", verifyToken, (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    try {
        let employeeid = (_a = req === null || req === void 0 ? void 0 : req.user) === null || _a === void 0 ? void 0 : _a.employeeid;
        const patients = yield prisma.patient.findMany({
            where: {
                prescriptions: {
                    some: {
                        employeeid: employeeid
                    }
                }
            },
            include: {
                reports: true
            }
        });
        return res.json({ patients });
    }
    catch (err) {
        console.error("Error fetching patients:", err);
        res.status(500).json({ error: "Internal server error" });
    }
}));
router.get("/patient/:id", verifyToken, (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const patientId = parseInt(req.params.id);
    if (isNaN(patientId)) {
        return res.status(400).json({ error: "Invalid patient ID" });
    }
    try {
        const patient = yield prisma.patient.findUnique({
            where: { patientid: patientId },
            include: {
                reports: true,
                prescriptions: {
                    include: {
                        employee: true
                    }
                }
            }
        });
        if (!patient) {
            return res.status(404).json({ error: "Patient not found" });
        }
        const doctorId = req.user.employeeid;
        const isAllowed = patient.prescriptions.some(p => p.employeeid === doctorId);
        if (!isAllowed) {
            return res.status(403).json({ error: "Access denied" });
        }
        return res.json({ patient });
    }
    catch (err) {
        console.error("Error fetching patient:", err);
        return res.status(500).json({ error: "Internal server error" });
    }
}));
router.get("/account", verifyToken, (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const employeeid = req.user.employeeid;
    try {
        const doctor = yield prisma.employee.findUnique({
            where: { employeeid },
            select: {
                employeeid: true,
                name: true,
                email: true,
                phone_number: true,
                role: true,
                prescribed: {
                    select: {
                        patient: {
                            select: {
                                patientid: true,
                                name: true,
                                age: true,
                                gender: true
                            }
                        }
                    }
                }
            }
        });
        if (!doctor) {
            return res.status(404).json({ error: "Employee not found" });
        }
        res.json({ account: doctor });
    }
    catch (err) {
        console.error("Error in /account:", err);
        res.status(500).json({ error: "Internal server error" });
    }
}));
/////////Mounting all the middlewares//////////
// Mounting JSON Checker
app.use("/", CheckBADJSON);
// MOunting router
app.use("/", router);
//////////////////////////////////////////////
const port = process.env.BACKEND_PORT || 8080;
app.listen(port, () => {
    console.log(`Backend running on port ${port}`);
});
