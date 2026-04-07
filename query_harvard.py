import requests

url = "https://qujkzrwrhrqejsqulohy.supabase.co/rest/v1/mountains?name=ilike.*Harvard*&select=*,routes:mountain_routes(*)"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF1amt6cndyaHJxZWpzcXVsb2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTQzMDYsImV4cCI6MjA4ODU3MDMwNn0.mdB8rjht5QtGcYmeEbNmYDlXLdsHcH9jzxmTOi4S28E",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF1amt6cndyaHJxZWpzcXVsb2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTQzMDYsImV4cCI6MjA4ODU3MDMwNn0.mdB8rjht5QtGcYmeEbNmYDlXLdsHcH9jzxmTOi4S28E"
}
response = requests.get(url, headers=headers)
print(response.json())
