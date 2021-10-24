FROM plugfox/flutter:stable

# Copy action app
COPY action_app/ /action_app/

# Get action app dependencies
RUN cd /action_app \
    && dart pub get
