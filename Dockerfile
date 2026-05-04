FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt

# we looked this up and there is no need to cache the packages, redundant data
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd app && chown -R app:app /app

USER app

EXPOSE 8000
# check
# we use CMD because we only have one server
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]