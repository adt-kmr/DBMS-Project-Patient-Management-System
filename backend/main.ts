import express, { Application, Request, Response, NextFunction } from "express"
import Log from "./logger.js";
import { PrismaClient } from './generated/prisma/client.js';
import { verifyToken } from './middlewares/verifyToken.js';
import  CheckBADJSON  from "./middlewares/JsonErrorChecker.js"
const prisma = new PrismaClient();

const app: Application = express();
const router = express.Router();
app.use(express.json());


//AUTH URL
/////////////////////////////////////////////////////////
const auth_url = "http://0.0.0.0:3000/login";////////////
/////////////////////////////////////////////////////////


router.get("/", (req: Request, res: Response) => {
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



router.post("/login", async (req: Request, res: Response) => {

    Log("/login", "POST", 200);

    console.log("19", req.body);
    let payload = req.body;
        if (!payload || !payload.email || !payload.password){
            res.json({
                error:"Bad Payload."
            });
        }
    let Response;
    try{
        Response = await fetch(auth_url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                email: payload.email,
                password: payload.password
            })
        });
    }
    catch(e){
        console.log("Some problem occured while contacting auth container. Error: "+e);
        res.json({
            error:"Unable to login, Some error occured in backend.",
            e:e
        });
    }
    if (Response) {
        let responce = await Response.json();
        console.log("Responce from auth container: ", responce);
        res.send(responce);
    } else {
        res.json({
            error: "Unable to login, Internal responce from server is undefined."
        });
    }
});

router.get("/patients", verifyToken, async (req: any, res: Response) => {
    try {
        let employeeid = req?.user?.employeeid;

        const patients = await prisma.patient.findMany({
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
    } catch (err) {
        console.error("Error fetching patients:", err);
        res.status(500).json({ error: "Internal server error" });
    }
});
router.get("/patient/:id", verifyToken, async (req: any, res: Response) => {
  const patientId = parseInt(req.params.id);

  if (isNaN(patientId)) {
    return res.status(400).json({ error: "Invalid patient ID" });
  }

  try {
    const patient = await prisma.patient.findUnique({
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

  } catch (err) {
    console.error("Error fetching patient:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
});

router.get("/account", verifyToken, async (req: any, res: Response) => {
  const employeeid = req.user.employeeid;

  try {
    const doctor = await prisma.employee.findUnique({
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

  } catch (err) {
    console.error("Error in /account:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});


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