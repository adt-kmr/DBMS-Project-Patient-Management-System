from django.contrib import admin
from .models import Employee, Patient, Prescribe, Report

@admin.register(Employee)
class EmployeeAdmin(admin.ModelAdmin):
    list_display = ('employeeid', 'name', 'email', 'role')
    search_fields = ('name', 'email', 'role')

@admin.register(Patient)
class PatientAdmin(admin.ModelAdmin):
    list_display = ('patientid', 'name', 'age', 'gender')
    search_fields = ('name', 'phone_number')

@admin.register(Prescribe)
class PrescribeAdmin(admin.ModelAdmin):
    list_display = ('id', 'employee', 'patient')
    search_fields = ('employee__name', 'patient__name')

@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = ('reportid', 'type', 'date_uploaded', 'patient')
    search_fields = ('type', 'patient__name')
