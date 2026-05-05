FROM python:3.11-slim

WORKDIR /app

# added dot after the txt file as destination  
COPY requirements.txt .

# we looked this up and there is no need to cache the packages, redundant data
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN python manage.py collectstatic --noinput


RUN useradd app && chown -R app:app /app

USER app

EXPOSE 8000
# check
# we use CMD because we only have one server
CMD ["gunicorn", "book_shop.wsgi:application", "--bind", "0.0.0.0:8000"]
