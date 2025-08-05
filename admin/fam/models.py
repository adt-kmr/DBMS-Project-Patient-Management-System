# app_name/models.py
from django.db import models

class Employee(models.Model):
    employeeid = models.AutoField(primary_key=True)
    name = models.CharField(max_length=100)
    phone_number = models.CharField(max_length=20, null=True, blank=True)
    email = models.CharField(max_length=100)
    pwd = models.CharField(max_length=255)
    role = models.CharField(max_length=50)

    def __str__(self):
        return f"{self.name} ({self.role})"
    
    class Meta:
        db_table = 'employees'  # Explicitly set the table name


class Patient(models.Model):
    patientid = models.AutoField(primary_key=True)
    name = models.CharField(max_length=100)
    age = models.IntegerField()
    gender = models.CharField(max_length=10)
    phone_number = models.CharField(max_length=20, null=True, blank=True)

    def __str__(self):
        return f"{self.name} ({self.gender}, {self.age})"
    
    class Meta:
        db_table = 'patients'  # Explicitly set the table name


class Prescribe(models.Model):
    id = models.AutoField(primary_key=True)
    
    employee = models.ForeignKey(
        Employee, 
        on_delete=models.CASCADE,
        db_column='employeeid'  # THIS tells Django what the column is actually called
    )
    
    patient = models.ForeignKey(
        Patient, 
        on_delete=models.CASCADE,
        db_column='patientid'  # 🔥 Same logic
    )

    def __str__(self):
        return f"{self.employee.name} → {self.patient.name}"

    class Meta:
        db_table = 'prescribe'
        managed = False



class Report(models.Model):
    reportid = models.AutoField(primary_key=True)
    
    patient = models.ForeignKey(
        Patient, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        db_column='patientid'  # 🩹 this is what Django was crying about
    )
    
    type = models.CharField(max_length=100, db_column='type')
    date_uploaded = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Report #{self.reportid} - {self.type}"

    class Meta:
        db_table = 'reports'
        managed = False  # since you're working with pre-existing tables

