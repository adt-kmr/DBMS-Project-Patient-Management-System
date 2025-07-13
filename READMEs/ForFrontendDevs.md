# Docs
- [1. API Documantation](#api-documentation)
- [1.1 Login](#login)
- [1.2 Get patients related to some specific docter](#12-patients)
- [1.3 Get information about paitent based on their patient id](#13-patientid)
- [1.4 Get information about the doctor](#)
## 1. API Documentation:
### 1.1 ./login
- Request type: `POST`
- For logging in, it expects JSON with email and password and will genrate JWT token.

Expected JSON:
```json
{"email":"email@email.com", "password":"password"}
```

- It checks the email and password and returns JSON which hold the JWT token. The returned JSON is like:
```json
{
  "token": "JWTTokenReturnedByTheBackend"
}
```
- If email and password are not provided, it returns ```{error:"Bad Payload."}```

### 1.2 ./patients
- Request Type: `GET`
- This endpoint returns the total patients which are prescribed to docter [or any other one] who is logged in.
- For example if you are a docter, then if you send a get request to patients endpoint then it will provided you JSON which will have all the patients.
- Returned JSON will be like:
```json
 {
  "patients":[ {
    "patientid": 123,
    "name": "Name",
    "age": 10,
    "gender": "M",
    "phone_number": 8289187289
  },
  ...
  ]
}
``` 
> NOTE: The Authorisation header **MUST** be provided in the request like `Authorization: Bearer token`, otherwise it will treat you to be not logined and will not know which doctor's patients are you asking about.

### 1.3 ./patient/:id
- Request Type: `GET`
- It will provided information about some specific patient based on there patient id
- an example api calll is like `./patient/123`

Respone JSON:
```json
    {
    "patientid": 123,
    "name": "Name",
    "age": 10,
    "gender": "M",
    "phone_number": 8289187289
  }
```

> NOTE: Once again, The Authorisation header **MUST** be provided in the request like `Authorization: Bearer token`.

- If Any other doctor ask about information about some patient who is not prescribed to that doctor
then, `{"error": "Access denied"}` 

### ./account
- It will provide information about doctor [who  is currently logged in] based on the JWT token.
- An example of JSON returned is
```JSON
{
  "account": {
    "employeeid": 3,
    "name": "Dr. AA",
    "email": "BB@hospital.com",
    "phone_number": "9876543210",
    "role": "doctor",
    "prescribed": [
      {
        "patient": {
          "patientid": 12,
          "name": "Shilpi Verma",
          "age": 100,
          "gender": "Male"
        }
      },
      ...
    ]
  }
}

```

> NOTE: Once again, The Authorisation header **MUST** be provided in the request like `Authorization: Bearer token`.