<template>
  <ion-page>
    <ion-header>
      <ion-toolbar>
        <ion-title>Profile</ion-title>
      </ion-toolbar>
    </ion-header>
    <ion-content :fullscreen="true">
      <ion-header collapse="condense">
        <ion-toolbar>
          <ion-title size="large">Profile</ion-title>
        </ion-toolbar>
      </ion-header>

      <!-- Content -->

      <!-- Profile Card -->
      <ion-card>
        <ion-card-header>
          <ion-grid>
            <ion-row>
              <ion-col size="2">
                <ion-avatar>
                  <img
                    src="https://i.insider.com/60904c2434af8d001859a9e1?width=910&format=jpeg"
                    alt="Profile Image"
                  />
                </ion-avatar>
              </ion-col>
              <ion-col
                class="ion-margin-start ion-align-items-center"
                :style="isAndroid && 'margin-top: 12px; margin-left: 24px'"
              >
                <ion-card-title :style="isAndroid && 'font-weight: 900'"
                  >Vitalik Buterin</ion-card-title
                >
                <ion-card-subtitle>0xf475D9...78F697bc</ion-card-subtitle>
              </ion-col>
            </ion-row>
          </ion-grid>
        </ion-card-header>
      </ion-card>

      <!-- End of Content -->
    </ion-content>
  </ion-page>
</template>

<script lang="ts">
import { defineComponent, ref } from 'vue';
import {
  isPlatform,
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonCard,
  IonCardHeader,
  IonCardTitle,
  IonCardSubtitle,
  // IonCardContent,
  IonRow,
  IonCol,
  IonAvatar,
  IonGrid,
} from '@ionic/vue';

export default defineComponent({
  name: 'Tab3Page',
  components: {
    IonHeader,
    IonToolbar,
    IonTitle,
    IonContent,
    IonPage,
    IonCard,
    // IonCardContent,
    IonCardHeader,
    IonCardTitle,
    IonCardSubtitle,
    IonRow,
    IonCol,
    IonAvatar,
    IonGrid,
  },
  setup() {
    const isAndroid = ref(isPlatform('android'));
    return { isAndroid };
  },
});
</script>
