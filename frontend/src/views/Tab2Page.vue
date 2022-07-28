<script lang="ts" setup>
import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonTextarea,
  IonLabel,
  IonItem,
} from '@ionic/vue';
</script>

<template>
  <ion-page>
    <ion-header>
      <ion-toolbar>
        <ion-title>New Post</ion-title>
      </ion-toolbar>
    </ion-header>
    <ion-content :fullscreen="true">
      <ion-header collapse="condense">
        <ion-toolbar>
          <ion-title size="large">New Post</ion-title>
        </ion-toolbar>
      </ion-header>
      
      <!-- Inputs -->
      <div class="ion-padding">
        <ion-item>
          <ion-textarea placeholder="Content" :rows="10" autofocus></ion-textarea>
        </ion-item>
      </div>
    </ion-content>
  </ion-page>
</template>
